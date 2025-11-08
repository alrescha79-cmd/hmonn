-- Full Path: /www/tinyfm/rootfs/usr/lib/lua/luci/model/cbi/huawey.lua
local fs  = require("nixio.fs")
local sys = require("luci.sys")

map = Map("huawey", "Huawei Configuration", "Configure Huawei router settings.")
map.description = [[
<p>Auto and Manual IP replacement for Huawei modems. Supports Orbit, E5577, E3372, and E5573 modems.</p>
]]

-- ========== IP Information ==========
section_ip_info = map:section(NamedSection, "settings", "huawey", "IP Information")
section_ip_info.addremove = false
section_ip_info.anonymous = true

-- Current IP (from GSM)
local current_ip = section_ip_info:option(DummyValue, "_current_ip", "Current IP")
current_ip.rawhtml = true
local ip_cache_file = "/tmp/last_ip.txt"
if fs.access(ip_cache_file) then
  -- Get IP from first line
  local ip_value = sys.exec("head -n 1 " .. ip_cache_file):gsub("\n", "")
  if ip_value and #ip_value > 0 then
    current_ip.value = '<span style="color:#0066cc; font-weight: bold;">' .. ip_value .. '</span>'
  else
    current_ip.value = '<span style="color:#999;">No IP detected</span>'
  end
else
  current_ip.value = '<span style="color:#999;">IP cache not available</span>'
end

-- Last IP Change (timestamp from file)
local last_change = section_ip_info:option(DummyValue, "_last_change", "Last IP Change")
last_change.rawhtml = true
if fs.access(ip_cache_file) then
  -- Get timestamp from second line
  local timestamp = sys.exec("sed -n '2p' " .. ip_cache_file):gsub("\n", "")
  if timestamp and #timestamp > 0 then
    last_change.value = '<span style="color:#006600;">' .. timestamp .. '</span>'
  else
    last_change.value = '<span style="color:#999;">No timestamp available</span>'
  end
else
  last_change.value = '<span style="color:#999;">IP cache not available</span>'
end

-- ========== Settings ==========
section = map:section(NamedSection, "settings", "huawey", "Settings")
section.addremove = false
section.anonymous = true

-- Router IP (stored in UCI huawey.settings.router_ip)
local router_ip = section:option(Value, "router_ip", "Router IP")
router_ip.datatype   = "ipaddr"
router_ip.default    = "192.168.8.1"
router_ip.placeholder= "Enter Modem Gateway IP"

-- Button to apply IP manually (without Save & Apply)
local apply_ip_btn = section:option(Button, "_apply_router_ip", "Apply Router IP")
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

-- Run Python script now (non-blocking) with lock to prevent multiple executions
local run_py_btn = section:option(Button, "_run_python_now", "Change IP Manually")
run_py_btn.inputstyle = "apply"
function run_py_btn.write(self, sid)
  local lock_file = "/tmp/huawei_change_ip.lock"
  -- Check if lock file exists and is recent (less than 60 seconds old)
  if fs.access(lock_file) then
    local lock_age = sys.exec("echo $(( $(date +%s) - $(stat -c %Y " .. lock_file .. " 2>/dev/null || echo 0) ))"):gsub("\n", "")
    if tonumber(lock_age) and tonumber(lock_age) < 60 then
      return -- Skip if already running recently
    end
  end
  -- Create lock file and run the script
  sys.call("touch " .. lock_file .. " && nohup python3 /usr/bin/huawei.py --change >/tmp/huawei.log 2>&1 && rm -f " .. lock_file .. " &")
end


-- Modem account
local username = section:option(Value, "username", "Username")
username.default    = "admin"
username.placeholder= "Enter Modem Username"

local password = section:option(Value, "password", "Password")
password.password   = true
password.default    = "admin"
password.placeholder= "Enter Modem Password"

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
mpath.placeholder  = "Script Path (/usr/bin/script.sh)"

-- ========== Service Control ==========
service_btn = section:option(Button, "_service", "Control Services")
service_btn.inputstyle = "apply"

status_title = section:option(DummyValue, "_status_title", "Status", "")
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
    status_title.value = '<span style="color:green; font-weight: bold;">Service is Running</span>'
  else
    service_btn.inputtitle = "Start Service"
    service_btn.inputstyle = "apply"
    status_title.value = '<span style="color:red; font-weight: bold;">Service is Stopped</span>'
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
