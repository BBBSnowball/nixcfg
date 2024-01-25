local webServicesInfo = require("webServicesInfo")

--local host = ngx.req.get_headers()["Host"]
local host = ngx.var.host
host = host:gsub(":.*", "")  -- remove port because we will change it

ngx.say([[
<!doctype html>
<meta charset="UTF-8" />
<link rel="shortcut icon" type="image/png" href="ha-nixos.png">
<link rel="stylesheet" href="index.css">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Home Assistant - Übersicht</title>

<ul>]])

for name,info in pairs(webServicesInfo) do
  if host:find("bettina%-home%.") then
    target = ngx.var.scheme .. "://" .. name .. "." .. host .. "/"
  else
    target = info.target:gsub("localhost", host)
  end

  ngx.say("  <li>")
  if info.icon == "" then
    ngx.say("    <span class=\"noimg\">&nbsp;</span>")
  else
    ngx.say("    <img src=\"" .. target .. info.icon .. "\"/>")
  end
  ngx.say("    <a href=\"" .. target .. "\">" .. info.title .. "</a>")
  ngx.say("  </li>")
end

ngx.say("</ul>")
