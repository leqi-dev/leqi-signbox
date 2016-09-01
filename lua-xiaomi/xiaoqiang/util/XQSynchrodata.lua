module ("xiaoqiang.util.XQSynchrodata", package.seeall)

local Json = require("cjson")

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")

local MessageClient = require("messageclient")
-- local MessageClient = {
--     ["send"] = function(x) end
-- }

function syncRouterName(name)
    if not XQFunction.isStrNil(name) then
        MessageClient.send("router_name", name)
    end
end

function syncRouterLocale(locale)
    local locale = tostring(locale)
    if not XQFunction.isStrNil(locale) then
        MessageClient.send("router_locale", locale)
    end
end

function syncWiFiSSID(wifi24, wifi5)
    if wifi24 then
        MessageClient.send("ssid_24G", wifi24)
    end
    if wifi5 then
        MessageClient.send("ssid_5G", wifi5)
    end
end

-- 0/1/2 普通/无线中继/有线中继
function syncWorkMode(mode)
    if mode then
        MessageClient.send("work_mode", tostring(mode))
    end
end

function syncApLanIp(ip)
    if ip then
        MessageClient.send("ap_lan_ip", tostring(ip))
    end
end

-- table: {mac, nickname, lan, wan, admin, pridisk}
function syncDeviceInfo(deviceinfo)
    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    if deviceinfo and deviceinfo.mac then
        local ndeviceinfo = {
            ["mac"]      = deviceinfo.mac,
            ["lan"]      = 1,
            ["wan"]      = 1,
            ["admin"]    = 1,
            ["nickname"] = "",
            ["pridisk"]  = 0,
            ["owner"]    = "",
            ["device"]   = ""
        }
        local payload = {
            ["api"] = 70,
            ["macs"] = {deviceinfo.mac}
        }
        local permission = {}
        local macFilterDict = XQDeviceUtil.getMacfilterInfoDict()
        local deviceConfInfo = XQDeviceUtil.fetchDeviceInfoFromConfig(deviceinfo.mac)
        local permissionResult = XQFunction.thrift_tunnel_to_datacenter(Json.encode(payload))
        if permissionResult and permissionResult.code == 0 then
            permission = permissionResult.canAccessAllDisk
        end
        local filter = macFilterDict[deviceinfo.mac]
        if filter then
            ndeviceinfo["wan"] = filter["wan"] and 1 or 0
            ndeviceinfo["lan"] = filter["lan"] and 1 or 0
            ndeviceinfo["admin"] = filter["admin"] and 1 or 0
            ndeviceinfo["pridisk"] = filter["pridisk"] and 1 or 0
        else
            ndeviceinfo["wan"] = 1
            ndeviceinfo["lan"] = 1
            ndeviceinfo["admin"] = 1
            ndeviceinfo["pridisk"] = 0
        end
        if permission[deviceinfo.mac] ~= nil then
            ndeviceinfo["lan"] = permission[deviceinfo.mac] and 1 or 0
        end
        if deviceConfInfo then
            ndeviceinfo["owner"] = deviceConfInfo.owner
            ndeviceinfo["device"] = deviceConfInfo.device
        end
        if deviceinfo.nickname then
            ndeviceinfo.nickname = deviceinfo.nickname
        else
            local XQDBUtil = require("xiaoqiang.util.XQDBUtil")
            local dbinfo = XQDBUtil.fetchDeviceInfo(deviceinfo.mac)
            if not XQFunction.isStrNil(dbinfo.nickname) then
                ndeviceinfo.nickname = dbinfo.nickname
            end
        end
        if deviceinfo.lan then
            ndeviceinfo.lan = deviceinfo.lan
        end
        if deviceinfo.wan then
            ndeviceinfo.wan = deviceinfo.wan
        end
        if deviceinfo.admin then
            ndeviceinfo.admin = deviceinfo.admin
        end
        if deviceinfo.pridisk then
            ndeviceinfo.pridisk = deviceinfo.pridisk
        end
        if deviceinfo.owner then
            ndeviceinfo.owner = deviceinfo.pridisk
        end
        if deviceinfo.device then
            ndeviceinfo.device = deviceinfo.device
        end
        MessageClient.send("device/"..deviceinfo.mac, Json.encode(ndeviceinfo))
    end
end