-- Full Path: /www/tinyfm/rootfs/usr/lib/lua/luci/model/cbi/huawey.lua
local fs  = require("nixio.fs")
local sys = require("luci.sys")

map = Map("huawey", "Huawei Configuration", "Configure Huawei router settings.")
map.description = [[
<p>Otomatisasi dan Manual penggantian IP untuk modem Huawei. Bisa untuk modem Orbit, E5577, E3372, dan E5573.</p>
]]

-- ========== Settings ==========
section = map:section(NamedSection, "settings", "huawey", "Settings")
section.addremove = false
section.anonymous = true

-- Router IP (disimpan di UCI huawey.settings.router_ip)
local router_ip = section:option(Value, "router_ip", "Router IP")
router_ip.datatype   = "ipaddr"
router_ip.default    = "192.168.8.1"
router_ip.placeholder= "Input IP Gateway Modem"

-- Tombol untuk menerapkan IP secara manual (tanpa Save & Apply)
local apply_ip_btn = section:option(Button, "_apply_router_ip", "Terapkan IP Router")
apply_ip_btn.inputstyle = "apply"
function apply_ip_btn.write(self, sid)
  local v = router_ip:formvalue(sid)
  if v and #v > 0 then
    sys.call(string.format(
      "uci set huawey.settings.router_ip='%s'; uci commit huawey",
      v
    ))
  end
end

-- Jalankan Python sekarang (non-blocking)
local run_py_btn = section:option(Button, "_run_python_now", "Ganti IP Manual")
run_py_btn.inputstyle = "apply"
function run_py_btn.write(self, sid)
  sys.call("nohup python3 /usr/bin/huawei.py --change >/tmp/huawei.log 2>&1 &")
end


-- Akun modem
local username = section:option(Value, "username", "Username")
username.default    = "admin"
username.placeholder= "Input Username your Modem"

local password = section:option(Value, "password", "Password")
password.password   = true
password.default    = "admin"
password.placeholder= "Input Password your Modem"

-- ========== Telegram ==========
section = map:section(NamedSection, "settings", "huawey", "Telegram")
section.addremove = false
section.anonymous = true

local token = section:option(Value, "telegram_token", "Telegram Token")
token.password     = true
token.default      = ""
token.placeholder  = "Telegram BOT Token"

local chatid = section:option(Value, "chat_id", "Chat ID")
chatid.default     = ""
chatid.placeholder = "Message Chat ID"

local threadid = section:option(Value, "message_thread_id", "Message Thread ID")
threadid.datatype  = "integer"
threadid.default   = 0
threadid.placeholder = "Message Thread ID Telegram"

-- ========== Duration & Path ==========
section = map:section(NamedSection, "settings", "huawey", "Duration")
section.addremove = false
section.anonymous = true

local pingdur = section:option(Value, "lan_off_duration", "Ping Duration (s)")
pingdur.datatype   = "uinteger"
pingdur.default    = 5
pingdur.placeholder= "Enter Ping Duration in second"

local mpath = section:option(Value, "modem_path", "Modem Path")
mpath.default      = "/usr/bin/huawei.py"
mpath.placeholder  = "Path Script (/usr/bin/script.sh)"

-- ========== Service Control ==========
service_btn = section:option(Button, "_service", "Control Services")
service_btn.inputstyle = "apply"

status_title = section:option(DummyValue, "_status_title", ".", "")
status_title.rawhtml = true

local function is_service_running()
  local rc_path = "/etc/rc.local"
  local script_line = "nohup python3 /usr/bin/huawei.py >/tmp/huawei.log 2>&1 &"
  -- local script_line = "/usr/bin/huawei -r"
  return fs.readfile(rc_path) and fs.readfile(rc_path):find(script_line, 1, true)
end

local function update_status()
  if is_service_running() then
    service_btn.inputtitle = "Stop Service"
    service_btn.inputstyle = "remove"
    status_title.value = '<span style="color:green;">Service is Running</span>'
  else
    service_btn.inputtitle = "Start Service"
    service_btn.inputstyle = "apply"
    status_title.value = '<span style="color:red;">Service is Stopped</span>'
  end
end

update_status()

function service_btn.write(self, section_id)
  local rc_path = "/etc/rc.local"
  local script_line = "nohup python3 /usr/bin/huawei.py >/tmp/huawei.log 2>&1 &"

  if is_service_running() then
    -- Stop
    luci.sys.call("huawei -s >/dev/null 2>&1")
    local rc_content = fs.readfile(rc_path)
    if rc_content then
      local new_content = rc_content:gsub(script_line:gsub("%-", "%%-") .. "\n?", "")
      fs.writefile(rc_path, new_content)
    end
  else
    -- Start
    luci.sys.call("huawei -r >/dev/null 2>&1 &")
    local rc = fs.readfile(rc_path) or ""
    if not rc:find(script_line, 1, true) then
      fs.writefile(rc_path, rc:gsub("exit 0", script_line .. "\nexit 0"))
    end
  end

  update_status()
end

return map
