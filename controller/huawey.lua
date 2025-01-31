module("luci.controller.huawey", package.seeall)

function index()
    -- Menambahkan entri di Luci
    entry({"admin", "services", "huawey"}, cbi("huawey"), _("Huawei Monitor"), 90).dependent = true
end
