module ("xiaoqiang.module.XQTopology", package.seeall)

local Json = require("cjson")

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")

local LuciUtil = require("luci.util")

function _recursive(item)
    local result = {
        ["ip"] = "",
        ["name"] = item.hostname or "",
        ["locale"] = item.locale or "",
        ["hardware"] = "",
        ["channel"] = "",
        ["mode"] = tonumber(item.is_ap),
        ["ssid"] = "",
        ["color"] = 100
    }
    local description = item.description
    if not XQFunction.isStrNil(item.description) then
        description = Json.decode(description)
        result.hardware = description.hardware
        result.channel = description.channel
        result.color = description.color
        result.ssid = description.ssid
        result.ip = description.ip
    end
    local leafs = {}
    if XQFunction.isStrNil(result.ip) and item.ip_list and #item.ip_list > 0 then
        local dev = item.ifname or ""
        for _, ip in ipairs(item.ip_list) do
            if (not dev:match("wl") or (dev:match("wl") and tonumber(item.assoc) == 1))
                and ip.ageing_timer <= 300 and (ip.tx_bytes ~= 0 or ip.rx_bytes ~= 0) then
                result.ip = ip.ip
                break
            end
        end
    end
    if item.child and #item.child > 0 then
        for _, newitem in ipairs(item.child) do
            if newitem.is_ap ~= 0 then
                table.insert(leafs, _recursive(newitem))
            end
        end
        if #leafs > 0 then
            result["leafs"] = leafs
        end
    end
    return result
end

function topologicalGraph()
    local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local wifi = XQWifiUtil.getWifiStatus(1) or {}
    local ubuscall = "ubus call trafficd hw '{\"tree\":true}'"
    local tree = LuciUtil.exec(ubuscall)

    local graph = {
        ["ip"] = XQLanWanUtil.getLanIp(),
        ["name"] = XQSysUtil.getRouterName(),
        ["locale"] = XQSysUtil.getRouterLocale(),
        ["hardware"] = XQSysUtil.getHardware(),
        ["channel"] = XQSysUtil.getChannel(),
        ["mode"] = XQFunction.getNetModeType(),
        ["color"] = XQSysUtil.getColor(),
        ["ssid"] = wifi.ssid or ""
    }
    if XQFunction.isStrNil(tree) then
        return graph
    else
        tree = Json.decode(tree)
    end

    local leafs = {}
    for key, item in pairs(tree) do
        if item.is_ap ~= 0 then
            table.insert(leafs, _recursive(item))
        end
    end
    if #leafs > 0 then
        graph["leafs"] = leafs
    end
    return graph
end