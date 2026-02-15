# This script applies our settings to mailinabox.
#
# This might seem like a job for Ansible but there are some issues with that:
# 1. There isn't any Ansible plugin for the mailinabox API, yet. The boilerplate
#    for such a plugin seems to be more than what we could save by using Ansible.
# 2. The ansible.builtin.copy module will simply copy the file with `shutil.copyfile`.
#    We would like to keep some state w.r.t. whether the update task has successfully
#    been run on that state.
# 3. The plugin will be called for each entry, so "remove all other aliases" seems to
#    not be supported (at least not easily).
# (Well, to be honest, some of this may be due to our limited knowledge of Ansible.)

import sys, tarfile, urllib, urllib.request, urllib.error, json, contextlib, os
import subprocess, re, datetime, glob

if len(sys.argv) == 2 and sys.argv[1] == "apply":
    check_mode = False
elif len(sys.argv) == 2 and sys.argv[1] == "dryrun":
    check_mode = True
else:
    print(f"Usage: {sys.argv[0]} (apply|dryrun)")
    sys.exit(1)

if not(isinstance(tar, tarfile.TarFile)):
    raise Exception("We must be called by the runner, which provides the TAR file to us!")

# copied from mailinabox (CC0-1.0 license), modified by us
# https://github.com/mail-in-a-box/mailinabox/blob/main/management/cli.py
# see here for available calls: https://mailinabox.email/api-docs.html
#
# The base URL for the management daemon. (Listens on IPv4 only.)
mgmt_uri = 'http://127.0.0.1:10222'
def mgmt(cmd, data=None, is_json=False):
        sys.stdout.flush()  # send any pending output messages (request might take a while or throw an error)
        req = urllib.request.Request(mgmt_uri + cmd, urllib.parse.urlencode(data).encode("utf8") if data else None)
        try:
                response = urllib.request.urlopen(req)
        except urllib.error.HTTPError as e:
                print(f"Error in request to mailinabox management server for {cmd}")
                if e.code == 401:
                        with contextlib.suppress(Exception):
                                print(e.read().decode("utf8"))
                        print("The management daemon refused access. The API key file may be out of sync. Try 'service mailinabox restart'.", file=sys.stderr)
                elif hasattr(e, 'read'):
                        print(e.read().decode('utf8'), file=sys.stderr)
                else:
                        print(e, file=sys.stderr)
                sys.exit(1)
        resp = response.read().decode('utf8')
        if is_json: resp = json.loads(resp)
        return resp
def setup_key_auth(mgmt_uri):
        with open('/var/lib/mailinabox/api.key', encoding='utf-8') as f:
                key = f.read().strip()

        auth_handler = urllib.request.HTTPBasicAuthHandler()
        auth_handler.add_password(
                realm='Mail-in-a-Box Management Server',
                uri=mgmt_uri,
                user=key,
                passwd='')
        opener = urllib.request.build_opener(auth_handler)
        urllib.request.install_opener(opener)
setup_key_auth(mgmt_uri)

# query version to test that we can talk to the management API
version = mgmt("/system/version")
print(f"mailinabox version: {version}")

def get_from_tar(expected_name):
    global tar
    tarinfo = tar.next()
    if tarinfo is None:
        raise Exception(f"Next member in tar should be {expected_name} but there aren't any more members")
    if tarinfo.name != expected_name:
        tar.list()
        raise Exception(f"Next member in tar should be {expected_name} but it is {tarinfo.name}")
    data = tar.extractfile(tarinfo).read()
    return data

def update_file_from_tar(expected_name, target_path):
    global check_mode
    if not os.path.exists(target_path):
        raise Exception(f"We only update existing files but {target_path} doesn't exist")

    data = get_from_tar(expected_name)
    with open(target_path, "rb") as f:
        current_data = f.read()
    if data == current_data:
        print(f"File is up-to-date: {target_path}")
        return False

    if check_mode:
        print(f"Changes that would be applied to {target_path}")
        sys.stdout.flush()
        subprocess.run(["diff", "-u", "--color=always", target_path, "-"], input=data)
    else:
        print(f"Updating file {target_path}")
        with open(target_path, "wb") as f:
            f.write(data)
    return True
# We have to trigger a web/dns update after changing these files.
# We would like to only update the file after we have applied the changes
# but Mailinabox will read it from that location. We could keep a `custom.yaml.current`
# to track the actual state but that also won't work because the web interface will
# update it for some changes and it will also edit dns/custom.yaml. Instead, we keep
# a separate state file to keep track of whether an update might be needed.
dns_changed = update_file_from_tar("dns.yaml", "/home/user-data/dns/custom.yaml")
web_changed = update_file_from_tar("www.yaml", "/home/user-data/www/custom.yaml")

pp = "+ "
pm = "- "
pn = "  "
def escape(x):
    #return repr(x)  # good enough, for now
    return "\"" + re.sub(r"([\\\"$])", r"\\\1x", x) + "\""
def print_alias(name, old, new):
    if old and not new:
        p = pm
    elif not old and new:
        p = pp
    else:
        p = pn
    print(f"{p}aliases.{escape(name)} = {{")
    if not old or not new or old["forwards_to"] != new["forwards_to"]:
        print(f"{p}  forwards_to = [")
        if old:
            for x in old["forwards_to"]:
                print(f"{pm}    {escape(x)}")
        if new:
            for x in new["forwards_to"]:
                print(f"{pp}    {escape(x)}")
        print(f"{p}  ];")
    if not old or not new or old["permitted_senders"] != new["permitted_senders"]:
        if old and old["permitted_senders"] is None:
            print(f"{pm}  permitted_senders = null;")
        elif old:
            print(f"{pm}  permitted_senders = [")
            for x in old["permitted_senders"]:
                print(f"{pm}    {escape(x)}")
            print(f"{pm}  ];")
        if new and new["permitted_senders"] is None:
            print(f"{pp}  permitted_senders = null;")
        elif new:
            print(f"{pp}  permitted_senders = [")
            for x in new["permitted_senders"]:
                print(f"{pp}    {escape(x)}")
            print(f"{pp}  ];")
    print(f"{p}}};")

default_user_values = {
    "status": "active",
    "privileges": [],
    "quota": "0",
    "box_quota": 0,
}
def print_user_if_different(name, old, new):
    if old and not new:
        p = pm
        diff = True
    elif not old and new:
        p = pp
        diff = True
    else:
        p = pn
        diff = False
    if diff:
        print(f"{p}users.{escape(name)} = {{")
    for prop in ("status", "privileges", "quota", "box_quota"):
        if old and prop not in old or new and prop not in new:
            continue
        if not old:
            print(f"{p}  {prop} = " + repr(new[prop]))
        elif not new:
            if prop not in default_user_values or default_user_values[prop] != old[prop]:
                print(f"{p}  {prop} = " + repr(old[prop]) + ";")
        elif old[prop] != new[prop]:
            if not diff:
                print(f"{p}{escape(name)} = {{")
                diff = True
            print(f"{pm}    {prop} = {repr(old[prop])};")
            print(f"{pp}    {prop} = {repr(new[prop])};")
        if new and new["status"] == "inactive":
            # don't compare other properties
            break
    if diff:
        print(f"{p}}};")
    return diff


expected_state = json.loads(get_from_tar("mail.json").decode("utf-8"))
expected_aliases = expected_state["aliases"]
for k,v in expected_aliases.items():
    if not isinstance(v, dict):
        v = { forwards_to: [v], permitted_senders: None }
        expected_aliases[k] = v
    if "permitted_senders" not in v:
        v["permitted_senders"] = None
    if not isinstance(v["forwards_to"], list):
        v["forwards_to"] = [v["forwards_to"]]

current_aliases = {}
for per_domain in mgmt("/mail/aliases?format=json", is_json=True):
    for alias in per_domain["aliases"]:
        if not alias["auto"]:
            current_aliases[alias["address"]] = alias

uptodate = 0
for k,v in current_aliases.items():
    if k not in expected_aliases:
        print_alias(k, v, None)
        if not check_mode:
            print(f"Remove alias {k}")
            print(mgmt("/mail/aliases/remove", { "address": k }))
for k,v in expected_aliases.items():
    should_update = False
    if k not in current_aliases:
        print_alias(k, None, v)
        should_update = True
        update_if_exists = 0
    else:
        v2 = current_aliases[k]
        if v["forwards_to"] != v2["forwards_to"] or v["permitted_senders"] != v2["permitted_senders"]:
            print_alias(k, v2, v)
            should_update = True
            update_if_exists = 1
        else:
            #print(f"Mail alias for {k} is up-to-date.")
            uptodate += 1
            should_update = False
    if not check_mode and should_update:
        print(f"Create or update alias {k}")
        request = {
            "address": k,
            "update_if_exists": update_if_exists,
            "forwards_to": "\n".join(v["forwards_to"]),
        }
        if v["permitted_senders"] is not None:
            request["permitted_senders"] = "\n".join(v["permitted_senders"])
        print(mgmt("/mail/aliases/add", request))
print(f"{uptodate} mail aliases are up-to-date.")

expected_users = expected_state["users"]
for k,v in expected_users.items():
    pass

uptodate = 0
current_users = {}
for per_domain in mgmt("/mail/users?format=json", is_json=True):
    for user in per_domain["users"]:
        name = user["email"]
        current_users[name] = user
        expected = expected_users.get(name)
        diff = print_user_if_different(name, user, expected)
        if not diff:
            uptodate += 1
        elif diff and should_update:
            if expected:
                print(f"*Manual action*: adjust user")
            else:
                print(f"*Manual action*: delete user")
for k,v in expected_users.items():
    if k not in current_users:
        print_user_if_different(name, None, v)
        print(f"*Manual action*: create user")
print(f"{uptodate} mail users are up-to-date.")

statefile = "/home/user-data/.update_state.json"
if os.path.exists(statefile):
    with open(statefile, "r") as f:
        state = json.load(f)
else:
    state = {}
state_changed = False

dns_mtime = os.stat("/home/user-data/dns/custom.yaml").st_mtime
web_mtime = os.stat("/home/user-data/www/custom.yaml").st_mtime

if state.get("dns_mtime", 0) != dns_mtime:
    dns_changed = True
if state.get("web_mtime", 0) != web_mtime:
    web_changed = True

if dns_changed:
    if check_mode:
        print("We would trigger a DNS update.")
    else:
        print("Updating DNS")
        print(mgmt("/dns/update", { "POSTDATA": "" }))
        state["dns_mtime"] = dns_mtime
        state_changed = True
if web_changed:
    if check_mode:
        print("We would trigger a web update.")
    else:
        print("Updating web")
        print(mgmt("/web/update", { "POSTDATA": "" }))
        state["web_mtime"] = web_mtime
        state_changed = True

if state_changed and not check_mode:
    with open(statefile, "w") as f:
        json.dump(state, f)

# Should we provision certs for any new domain?
# We could ask with `/ssl/status` but that takes 14 seconds. The status is mostly
# human-readable text but it does have the entry "can_provision" with the new domains.
# We don't want to run this every time, so we manually provide a list of domains that
# should have a cert.
available_certs = {}
for keyfile in glob.glob(f"/home/user-data/ssl/*-*.pem"):
    p = subprocess.run(["openssl", "x509", "-enddate", "-ext", "subjectAltName", "-subject", "-noout", "-in", keyfile], stdout=subprocess.PIPE)
    text = p.stdout.decode("utf-8")
    m = re.search(r"^notAfter=(.*)$", text, re.MULTILINE)
    if not m:
        print(f"Couldn't find expire date in {keyfile}")
        continue
    # date is formatted as rfc_822
    enddate = datetime.datetime.strptime(m[1], "%b %d %H:%M:%S %Y %Z")

    domains = []
    m = re.search(r"^subject=CN *= *(.*)$", text, re.MULTILINE)
    if m:
        domains.append(m[1])
    for m in re.findall(r"[, ]DNS:([^, \r\n]+)([, ]|$)", text, re.MULTILINE):
        domains.append(m[0])
    for domain in domains:
        if domain not in available_certs or available_certs[domain] < enddate:
            available_certs[domain] = enddate

now = datetime.datetime.now()
missing_certs = []
for domain in expected_state["ssl_domains"]:
    if domain not in available_certs:
        print(f"INFO: {domain} doesn't have any cert, yet")
        missing_certs.append(domain)
    elif available_certs[domain] > now:
        #print(f"{domain} is valid for {(available_certs[domain]-now).days} days")
        pass
    else:
        print(f"WARN: {domain} has an outdated cert ({available_certs[domain].strftime('%Y-%m-%d')})")

if len(missing_certs) > 0 and check_mode:
    # Check for cert status takes a long time, so we skip it in check mode.
    # The check might also yield the wrong result in check mode, namely if we are going to add the first
    # mail address for a domain but haven't done so yet because of check mode.
    print(f"INFO: We have {len(missing_certs)} missing certs. We would try and provision them.")
elif len(missing_certs) > 0:
    print(f"We have {len(missing_certs)} missing certs. Let's see whether we can provision them.")
    certstate = mgmt("/ssl/status", is_json=True)
    cannot_be_provisioned = []
    do_provision = False
    for domain in missing_certs:
        if domain in certstate["can_provision"]:
            do_provision = True
        else:
            print(f"ERROR: Domain {domain} cannot be provisioned!")
            cannot_be_provisioned.append(domain)
            for x in certstate["status"]:
                if x["domain"] == domain:
                    print("  " + x["text"])

    if do_provision:
        if check_mode:
            # The list can include some that we are not asking for. We cannot choose. Mailinabox will only provision a domain
            # if that makes sense, so this should be fine.
            print("We would provision the new domains. This will create certs for: " + ", ".join(certstate["can_provision"]))
        else:
            print("We will provision the new domains. This will create certs for: " + ", ".join(certstate["can_provision"]))
            print(mgmt("/ssl/provision", { "POSTDATA": "" }))
    if len(cannot_be_provisioned) > 0:
        print("ERROR: We cannot provision certs for these domains: " + ", ".join(cannot_be_provisioned))

