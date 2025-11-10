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

-- Modem account
local username = section:option(Value, "username", "Username")
username.default    = "admin"
username.placeholder= "Enter Modem Username"

local password = section:option(Value, "password", "Password")
password.password   = true
password.default    = "admin"
password.placeholder= "Enter Modem Password"

-- Status message for IP change
local ip_change_status = section:option(DummyValue, "_ip_change_status", "")
ip_change_status.rawhtml = true
ip_change_status.value = '<div id="ip_change_status" style="display:none; padding:10px; border-radius:5px; margin-top:10px;"></div>'

-- Run Python script now (non-blocking) with lock to prevent multiple executions
local run_py_btn = section:option(Button, "_run_python_now", "Change IP Manually")
run_py_btn.inputstyle = "apply"
run_py_btn.rawhtml = true

-- Add JavaScript for loading animation - inject at the bottom of the page
run_py_btn.description = [=[
<script type="text/javascript">
//<![CDATA[
(function() {
  // Prevent double initialization
  if (window.huaweiChangeIpInitialized) return;
  window.huaweiChangeIpInitialized = true;
  
  console.log('Initializing Change IP button handler...');
  
  function showStatus(type, message) {
    var statusDiv = document.getElementById('ip_change_status');
    if (!statusDiv) {
      console.error('Status div not found!');
      return;
    }
    
    statusDiv.style.display = 'block';
    
    if (type === 'loading') {
      statusDiv.style.backgroundColor = '#fff3cd';
      statusDiv.style.color = '#856404';
      statusDiv.style.border = '1px solid #ffeeba';
      statusDiv.innerHTML = '<div style="display:flex; align-items:center;"><div class="spinner"></div><span><strong>🔄 Mencari IP baru...</strong> Mohon tunggu beberapa saat.</span></div>';
    } else if (type === 'success') {
      statusDiv.style.backgroundColor = '#d4edda';
      statusDiv.style.color = '#155724';
      statusDiv.style.border = '1px solid #c3e6cb';
      statusDiv.innerHTML = '<strong>✓ Berhasil!</strong> ' + message;
    } else if (type === 'error') {
      statusDiv.style.backgroundColor = '#f8d7da';
      statusDiv.style.color = '#721c24';
      statusDiv.style.border = '1px solid #f5c6cb';
      statusDiv.innerHTML = '<strong>✗ Gagal!</strong> ' + message;
    }
  }
  
  function checkStatus() {
    var checkCount = 0;
    var maxChecks = 15;
    
    var checkInterval = setInterval(function() {
      checkCount++;
      
      fetch('/cgi-bin/luci/admin/network/huawey_status?t=' + new Date().getTime())
        .then(function(response) { return response.text(); })
        .then(function(data) {
          console.log('Status check ' + checkCount + ': ' + data.trim());
          
          if (data.indexOf('complete') !== -1) {
            clearInterval(checkInterval);
            showStatus('success', 'IP baru telah ditemukan dan diterapkan. Halaman akan dimuat ulang dalam 7 detik...');
            setTimeout(function() {
              window.location.reload();
            }, 7000);
          } else if (data.indexOf('error') !== -1) {
            clearInterval(checkInterval);
            showStatus('error', 'Terjadi kesalahan saat mencari IP baru. Silakan coba lagi.');
          } else if (checkCount >= maxChecks) {
            clearInterval(checkInterval);
            showStatus('success', 'Proses selesai! Halaman akan dimuat ulang untuk menampilkan IP terbaru...');
            setTimeout(function() {
              window.location.reload();
            }, 7000);
          }
        })
        .catch(function(err) {
          console.error('Error checking status:', err);
          if (checkCount >= maxChecks) {
            clearInterval(checkInterval);
            showStatus('error', 'Timeout! Halaman akan dimuat ulang...');
            setTimeout(function() {
              window.location.reload();
            }, 2000);
          }
        });
    }, 2000);
  }
  
  function initButton() {
    // Find the form that contains our button
    var forms = document.querySelectorAll('form');
    var targetForm = null;
    
    for (var i = 0; i < forms.length; i++) {
      var buttons = forms[i].querySelectorAll('input[type="submit"]');
      for (var j = 0; j < buttons.length; j++) {
        if (buttons[j].value && 
            (buttons[j].value.indexOf('Change IP') !== -1 || 
             buttons[j].value.indexOf('Manually') !== -1)) {
          targetForm = forms[i];
          console.log('Found Change IP button:', buttons[j].value);
          
          // Intercept form submission
          buttons[j].onclick = function(e) {
            console.log('Change IP button clicked!');
            
            // Show loading status immediately
            showStatus('loading', '');
            
            // Prevent default form submission
            e.preventDefault();
            e.stopPropagation();
            
            // Submit form via AJAX
            var formData = new FormData(targetForm);
            // Add the button name and value to trigger the write function
            formData.append('cbi.apply', 'Change IP Manually');
            formData.append('cbid.huawey.settings._run_python_now', 'Change IP Manually');
            
            console.log('Submitting form with FormData...');
            
            fetch(targetForm.action || window.location.href, {
              method: 'POST',
              body: formData
            })
            .then(function(response) {
              console.log('Form submitted successfully, status:', response.status);
              return response.text();
            })
            .then(function(html) {
              console.log('Response received, starting status check...');
              // Start checking status
              setTimeout(checkStatus, 1000);
            })
            .catch(function(err) {
              console.error('Error submitting form:', err);
              showStatus('error', 'Gagal mengirim perintah ke server.');
            });
            
            return false;
          };
          
          return true;
        }
      }
    }
    
    console.log('Change IP button not found yet...');
    return false;
  }
  
  // Try to init immediately
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      setTimeout(initButton, 100);
    });
  } else {
    setTimeout(initButton, 100);
  }
  
  // Retry a few times in case the button loads dynamically
  var retryCount = 0;
  var retryInterval = setInterval(function() {
    retryCount++;
    if (initButton() || retryCount >= 10) {
      clearInterval(retryInterval);
    }
  }, 500);
})();
//]]>
</script>
<style type="text/css">
.spinner {
  border: 3px solid #f3f3f3;
  border-top: 3px solid #856404;
  border-radius: 50%;
  width: 20px;
  height: 20px;
  animation: spin 1s linear infinite;
  margin-right: 10px;
}
@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>
]=]

function run_py_btn.write(self, sid)
  local lock_file = "/tmp/huawei_change_ip.lock"
  local status_file = "/tmp/huawei_change_ip_status.txt"
  
  -- Log untuk debugging
  sys.call("echo '[DEBUG] run_py_btn.write() called at $(date)' >> /tmp/huawei_debug.log")
  
  -- Check if lock file exists and is recent (less than 60 seconds old)
  if fs.access(lock_file) then
    local lock_age = sys.exec("echo $(( $(date +%s) - $(stat -c %Y " .. lock_file .. " 2>/dev/null || echo 0) ))"):gsub("\n", "")
    if tonumber(lock_age) and tonumber(lock_age) < 60 then
      sys.call("echo '[DEBUG] Lock file exists, skipping...' >> /tmp/huawei_debug.log")
      return -- Skip if already running recently
    end
  end
  
  -- Reset status file
  sys.call("echo 'running' > " .. status_file)
  sys.call("echo '[DEBUG] Status set to running' >> /tmp/huawei_debug.log")
  
  -- Create lock file and run the script with status update
  sys.call("touch " .. lock_file .. " && (python3 /usr/bin/huawei.py --change >/tmp/huawei.log 2>&1 && echo 'complete' > " .. status_file .. " || echo 'error' > " .. status_file .. ") && rm -f " .. lock_file .. " &")
  sys.call("echo '[DEBUG] Python script started' >> /tmp/huawei_debug.log")
end

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
