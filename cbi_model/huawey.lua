local map, section, option

map = Map("huawey", "Huawei Configuration", "Configure Huawei router settings.")
map.description = [[
<p>This tool helps to configure settings for various Huawei modem types including Orbit, E5577, E3372, and E5573.</p>
<p>Use this tool conn monitor or cron "python3 /usr/bin/huawei.py"</p>
<br>
<p>Tutorial this <a href="https://bit.ly/aryochannel" target="_blank">HERE</a></p>
]]

section = map:section(NamedSection, "settings", "huawey", "Settings")
section.addremove = false
section.anonymous = true

option = section:option(Value, "router_ip", "Router IP")
option.datatype = "ipaddr"
option.default = "192.168.8.1"

option = section:option(Value, "username", "Username")
option.default = "admin"

option = section:option(Value, "password", "Password")
option.password = true
option.default = "admin"

option = section:option(Value, "telegram_token", "Telegram Token")
option.default = ""

option = section:option(Value, "chat_id", "Chat ID")
option.default = ""

option = section:option(Value, "message_thread_id", "Message Thread ID")
option.datatype = "integer"
option.default = 0


return map
