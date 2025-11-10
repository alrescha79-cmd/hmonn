module("luci.controller.huawey", package.seeall)

function index()
    -- Menambahkan entri di Luci
    entry({"admin", "services", "huawey"}, cbi("huawey"), _("Huawei Monitor"), 90).dependent = true
    
    -- Endpoint untuk memeriksa status perubahan IP
    entry({"admin", "network", "huawey_status"}, call("check_ip_change_status"), nil).leaf = true
end

function check_ip_change_status()
    local fs = require("nixio.fs")
    local status_file = "/tmp/huawei_change_ip_status.txt"
    
    if fs.access(status_file) then
        local status = fs.readfile(status_file)
        luci.http.prepare_content("text/plain")
        luci.http.write(status)
    else
        luci.http.prepare_content("text/plain")
        luci.http.write("unknown")
    end
end

