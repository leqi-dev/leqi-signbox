module ("xiaoqiang.module.XQPredownload", package.seeall)

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")

function predownloadInfo()
    local uci = require("luci.model.uci").cursor()
    local info = {}
    info["auto"] = tonumber(uci:get("otapred", "settings", "auto")) or 0
    info["time"] = tonumber(uci:get("otapred", "settings", "time")) or 4
    info["priority"] = tonumber(uci:get("otapred", "settings", "priority")) or 0
    return info
end

function setPredownload(priority, auto, time)
    local uci = require("luci.model.uci").cursor()
    if tonumber(priority) then
        uci:set("otapred", "settings", "priority", priority)
    end
    if tonumber(auto) then
        uci:set("otapred", "settings", "auto", auto)
    end
    if tonumber(auto) and tonumber(auto) == 1 then
        uci:set("otapred", "settings", "updateurl", "")
    end
    if tonumber(time) and tonumber(time) >= 0 and tonumber(time) < 24 then
        uci:set("otapred", "settings", "time", time)
    end
    uci:commit("otapred")
end

function switch(on)
    if on then
        return os.execute("/etc/init.d/predownload-ota start") == 0
    else
        return os.execute("/etc/init.d/predownload-ota stop") == 0
    end
end

function reload()
    os.execute("/etc/init.d/predownload-ota restart")
end