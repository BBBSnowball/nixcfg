function loadData() {
  var x = new XMLHttpRequest();
  x.addEventListener("load", function (e) {
    console.log(e);
    //showData(JSON.parse(e.response));
    showData(x.response);
  });
  x.addEventListener("error", function (e) {
    console.log("error", e);
    document.getElementById("groups").innerText = "Error while loading data: " + e;
  });
  x.addEventListener("abort", function (e) {
    console.log("abort", e);
    document.getElementById("groups").innerText = "Error while loading data: " + e;
  });
  x.open("GET", "/get_data");
  x.responseType = "json";
  x.send();
  return x;
}

var groups = {};
var users = {};

function showData(data) {
  users = {};
  groups = {};
  for (var i=0; i<data.radusergroup.length; i++) {
    var x = data.radusergroup[i];
    if (!users[x.username])
      users[x.username] = { groups: [] };
    if (!groups[x.groupname])
      groups[x.groupname] = { users: [], vlan: null, attrs: [] };
    users[x.username].groups.push(x.groupname);
    groups[x.groupname].users.push(x.username);
  }
  for (var i=0; i<data.radgroupreply.length; i++) {
    var x = data.radgroupreply[i];
    if (!groups[x.groupname])
      groups[x.groupname] = { users: [], vlan: null, attrs: [] };
    groups[x.groupname].attrs.push(x.attribute + " " + x.op + " " + x.value);
  }
  for (var i=0; i<data.radpostauth.length; i++) {
    var x = data.radpostauth[i];
    if (!users[x.username] && x.reply == "Access-Accept")
      users[x.username] = { groups: [] };
  }

  var groupsDiv = document.getElementById("groups");
  groupsDiv.innerHTML = "";
  var y = document.createElement("DIV");
  y.innerText = "Groups:";
  y.classList.add("header");
  groupsDiv.appendChild(y);

  for (var name in groups) {
    var x = groups[name];
    var y = document.createElement("DIV");
    y.innerText = name;
    y.classList.add("group");
    y.classList.add("hl_group_" + name);
    for (var i=0; i<x.users.length; i++) {
      y.classList.add("hl_user_" + x.users[i]);
    }
    y.setAttribute("data_highlight_class", "hl_group_" + name);
    y.addEventListener("mouseenter", highlight, false);
    y.addEventListener("mouseleave", highlight, false);

    y.classList.add("tooltip_parent");
    var t = document.createElement("span");
    t.classList.add("tooltip");
    t.innerText = (x.attrs.length == 0 ? "- no attributes -" : x.attrs.join("\n"));
    y.appendChild(t);

    groupsDiv.appendChild(y);
  }

  var usersDiv = document.getElementById("users");
  usersDiv.innerHTML = "";
  var y = document.createElement("DIV");
  y.innerText = "Users:";
  y.classList.add("header");
  usersDiv.appendChild(y);

  for (var name in users) {
    var x = users[name];
    var y = document.createElement("DIV");
    y.innerText = name;
    y.classList.add("user");
    y.classList.add("hl_user_" + name);
    for (var i=0; i<x.groups.length; i++) {
      y.classList.add("hl_group_" + x.groups[i]);
    }
    y.setAttribute("data_highlight_class", "hl_user_" + name);
    y.addEventListener("mouseenter", highlight, false);
    y.addEventListener("mouseleave", highlight, false);
    usersDiv.appendChild(y);
  }

  var authDiv = document.getElementById("auth");
  authDiv.innerHTML = "";
  var table = document.createElement("table");
  table.innerHTML = "<thead><tr><th>Time</th><th>User</th><th>Reply</th></tr></thead>";
  var tbody = document.createElement("tbody");
  for (var i=0; i<data.radpostauth.length; i++) {
    var x = data.radpostauth[i];
    var y = document.createElement("TR");
    y.innerHTML = "<td>x</td><td>y</td><td>z</td>";
    y.children[0].innerText = x.authdate;
    y.children[1].innerText = x.username;
    y.children[2].innerText = x.reply;
    y.children[1].classList.add("hl_user_" + x.username);
    if (x.reply == "Access-Accept")
      y.children[2].classList.add("auth_accept");
    else if (x.reply == "Access-Reject")
      y.children[2].classList.add("auth_reject");
    tbody.appendChild(y);
  }
  table.appendChild(tbody);
  authDiv.appendChild(table);
}

function highlight(e) {
  console.log(e);

  var hl = null;
  if (e.type == "mouseenter") {
    hl = true;
  } else if (e.type == "mouseleave") {
    hl = false;
  }
  console.log(hl);

  if (hl !== null) {
    var cls = e.target.getAttribute("data_highlight_class");
    var xs = document.querySelectorAll("." + e.target.getAttribute("data_highlight_class"));
    for (var i=0; i<xs.length; i++) {
      var x = xs[i].getAttribute("data_current_highlights") || "";
      if (hl)
        x = x.replace("," + cls, "") + "," + cls;
      else
        x = x.replace("," + cls, "").replace("," + cls, "");
      xs[i].setAttribute("data_current_highlights", x);
      if (x == "")
        xs[i].classList.remove("highlight");
      else
        xs[i].classList.add("highlight");
    }
  }
}

loadData();