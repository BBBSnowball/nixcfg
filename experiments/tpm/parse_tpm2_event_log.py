# https://github.com/google/go-attestation/blob/master/attest/eventlog.go#L588
# https://lists.ofono.org/hyperkitty/list/tpm2@lists.01.org/thread/PVR5UPADM6VYITAADIZUHWCMBD3MIEPL/
# https://trustedcomputinggroup.org/wp-content/uploads/EFI-Protocol-Specification-rev13-160330final.pdf
# https://trustedcomputinggroup.org/wp-content/uploads/TCG-EFI-Platform-Specification.pdf
import struct, sys, hashlib, binascii
d = sys.stdin.buffer.read()
i = 0

num_pcrs = 16
pcrs = {4: [b'\x00' * 20] * num_pcrs}

event_names = {
    1: ("EV_POST_CODE", "EFI_PLATFORM_FIRMWARE_BLOB"),
    4: ("EV_SEPARATOR", "null"),
    8: ("EV_S_CRTM_VERSION", "version string"),
    7: ("EV_S_CRTM_CONTENTS", "EFI_PLATFORM_FIRMWARE_BLOB"),
    0x80000001: ("EV_EFI_VARIABLE_DRIVER_CONFIG", "EFI_VARIABLE_DATA"),
    0x80000002: ("EV_EFI_VARIABLE_BOOT", "EFI_VARIABLE_DATA"),
    0x80000003: ("EV_EFI_BOOT_SERVICES_APPLICATION", "EFI_IMAGE_LOAD_EVENT"),
    0x80000004: ("EV_EFI_BOOT_SERVICES_DRIVER", "EFI_IMAGE_LOAD_EVENT"),
    0x80000005: ("EV_EFI_RUNTIME_SERVICES_DRIVER", "EFI_IMAGE_LOAD_EVENT"),
    0x80000006: ("EV_EFI_GPT_EVENT", "EFI_GPT_DATA"),
    0x80000007: ("EV_EFI_ACTION", "string"),
    0x80000008: ("EV_EFI_PLATFORM_FIRMWARE_BLOB", "EFI_PLATFORM_FIRMWARE_BLOB"),
    0x80000009: ("EV_EFI_HANDOFF_TABLES", "EFI_HANDOFF_TABLE_POINTERS"),

    13: ("kernel cmdline", "utf16"),
}

def get(fmt):
    global d, i
    x = struct.unpack_from(fmt, d, i)
    i += struct.calcsize(fmt)
    return x
def getn(n):
    global d, i
    x = d[i:i+n]
    i += n
    return x

def extend(pcr, alg, digest, data):
    global pcrs
    if alg == 4:
        h = hashlib.sha1()
        h2 = hashlib.sha1()
    elif alg == 11:
        h = hashlib.sha256()
        h2 = hashlib.sha256()
    else:
        return
    h.update(pcrs[alg][pcr])
    h.update(digest)
    pcrs[alg][pcr] = h.digest()

    #h2.update(data)
    #digest2 = h2.digest()
    #if digest != digest2:
    #    print("ERROR: digest mismatch")

def print_data(dtype, data):
    if dtype == "EFI_PLATFORM_FIRMWARE_BLOB" and len(data) == 16:
        base, length = struct.unpack("QQ", data)
        print("  base=%08x, length=%08x" % (base, length))
    elif dtype == "EFI_VARIABLE_DATA":
        i = 0
        while i < len(data):
            guid,namelen,dlen = struct.unpack_from("16sQQ", data, i)
            i += 32
            name = data[i:i+2*namelen].decode('utf-16')
            i += 2*namelen
            vdata = data[i:i+dlen]
            i += dlen
            print("  EFI_VARIABLE_DATA:", repr((name, vdata, guid)))
    elif dtype == "EFI_IMAGE_LOAD_EVENT":
        location, length, link_time_address, lpath = struct.unpack_from("QQQQ", data)
        i = 32
        print("  location=%08x, length=%08x, link_time_address=%08x" % (location, length, link_time_address))
        #print("  path=%r" % data[i:i+lpath])
        print_path(data[i:i+lpath])
        i += lpath
        if i != len(data):
            print("WARN: length mismatch, %d, %d" % (i, len(data)))
    elif dtype == "utf16":
        print("    %r" % ((data+b'\0').decode('utf16')))
    else:
        print("    ", data)

dpath_type = {
    1: "hardware",
    2: "acpi",
    3: "message",
    4: "media",
    5: "bios",
    0x7f: "end"
}
dpath_subtype = {
    1: {
        1: "pci",
        2: "pccard",
        3: "mmapped",
        4: "vendor",
        5: "controller",
    },
    4: {
        1: "hard drive",
        2: "cdrom",
        3: "vendor",
        4: "file",
        5: "protocol",
        7: "piwg volume",
        6: "piwg file",
        8: "relative offset range",
    },
    0x7f: {
        1: "end instance",
        0xff: "end path"
    }
}

def print_path(data):
    i = 0
    while i < len(data):
        type, subtype, length = struct.unpack_from("BBH", data, i)
        x = data[i+4:i+length]
        i += length
        x2 = x

        if type == 4 and subtype == 4:
            name = x.decode('utf-16')
            x2 = repr(name)
        elif type == 4 and subtype == 8 and len(x) == 20:
            dummy, = struct.unpack_from("I", x, 0)
            start, end = struct.unpack_from("QQ", x, 4)
            x2 = "start=%08x, end=%08x, dummy=%08x" % (start, end, dummy)

        if type in dpath_subtype and subtype in dpath_subtype[type]:
            subtype = dpath_subtype[type][subtype]
        if type in dpath_type:
            type = dpath_type[type]
        print("    ", repr((type, subtype, len(x), x2)))

algos_dict = {}
def parse1():
    global d, i, parse_fn, algos_dict, pcrs
    index, type, digest, size = get("<II20sI")
    print(repr((index, type, digest, size)))
    end = i + size
    if type == 3:
        print("switching to TPM2 format")
        parse_fn = parse2
        h = get("16sIBBBBI")
        print(h)
        algos = [get("HH") for k in range(h[6])]
        print(repr(algos))
        for (alg, size) in algos:
            if alg not in pcrs:
                pcrs[alg] = [b'\x00' * size] * num_pcrs
        algos_dict = dict(algos)
        vsize, = get("B")
        vendor_data = getn(vsize)
        print(repr(vendor_data))
        if vsize != end:
            print("expected %d == %d" % (vsize, end))
    else:
        extend(index, 4, digest, d[i:end])
    i = end

def parse2():
    global d, i, algos_dict, event_names
    index, type, num_digest = get("III")
    if type in event_names:
        type = event_names[type]
    else:
        type = (type, "?")
    print(repr((index, type, num_digest)))
    digests = []
    for j in range(num_digest):
        alg, = get("H")
        digest = getn(algos_dict[alg])
        if type[1] == "EFI_PLATFORM_FIRMWARE_BLOB" or type[1] == "EFI_IMAGE_LOAD_EVENT":
            print("  ", repr((alg, binascii.hexlify(digest))))
        digests.append((alg, digest))
    size, = get("I")
    data = getn(size)
    #print("    ", repr(data))
    print_data(type[1], data)
    for alg, digest in digests:
        extend(index, alg, digest, data)

parse_fn = parse1
while i < len(d):
    parse_fn()
if i != len(d):
    print("ERROR: length mismatch: %d != %d" % (i, len(d)))

for alg, xs in pcrs.items():
    print("algo %d:" % alg)
    for index, pcr in enumerate(xs):
        print(index, binascii.hexlify(pcr).upper())

