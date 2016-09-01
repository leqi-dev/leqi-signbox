module ("xiaoqiang.XQPushHelper", package.seeall)

local bit = require("bit")
local Json = require("json")

local LuciUtil = require("luci.util")

local XQLog = require("xiaoqiang.XQLog")
local XQPreference = require("xiaoqiang.XQPreference")
local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")
local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
local XQPushUtil = require("xiaoqiang.util.XQPushUtil")
local XQCacheUtil = require("xiaoqiang.util.XQCacheUtil")

WIFI_CLEAR = false

PUSH_DEFAULT_MESSAGE_TITLE = "新消息"
PUSH_DEFAULT_MESSAGE_DESCRIPTION = "您有一条新消息"

PUSH_INTERVAL = 1800

PUSH_MESSAGE_TITLE = {
    "系统升级",
    "备注设备上线",
    "陌生设备上线",
    "所有WiFi设备离线",
    "下载完成",
    "智能场景",
    "网络检测",
    "加速相关",
    "%s有更新，请升级！"
}

PUSH_MESSAGE_DESCRIPTION = {
    "路由器已经升级到最新版",
    "备注设备上线",
    "陌生设备上线",
    "所有WiFi设备离线",
    "全部下载任务已经完成",
    "智能场景已经完成",
    "网络检测已经完成",
    "加速提醒",
    "发现新版本%s（%s）"
}

function _formatStr(str)
    local str = string.gsub(str,"\"","\\\"")
    str = string.gsub(str, ";", "\\;")
    str = string.gsub(str, "&", "\\&")
    return str:gsub(" ","")
end

-- function _parserFlag(flag)
--     local result = {
--         ["f"] = false,
--         ["p"] = true
--     }
--     local flag = tonumber(flag)
--     if flag then
--         if bit.band(flag, 0x01) == 0x01 then
--             result.p = true
--         else
--             result.p = false
--         end
--         if bit.band(flag, 0x02) == 0x02 then
--             result.f = true
--         else
--             result.f = false
--         end
--     end
--     return result
-- end

-- function _parserPushType(ptype)
--     local flag = "0x01"
--     local ptype = tostring(ptype)
--     if ptype then
--         flag = XQPreference.get(ptype, "0x01", "push")
--     end
--     return _parserFlag(flag)
-- end

function _doPush(payload, title, description, ptype)
    if not payload or not title or not description then
        return
    end
    payload = _formatStr(payload)
    local pushtype = "1"
    if ptype then
        pushtype = tostring(ptype)
    end
    os.execute(string.format("pushClient %s %s %s %s", payload, title, description, pushtype))
end

function _hookSysUpgraded()
    local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
    local ver = XQSysUtil.getRomVersion()
    local payload = {
        ["type"] = 1,
        ["ver"] = ver
    }
    _doPush(Json.encode(payload), PUSH_MESSAGE_TITLE[1], PUSH_MESSAGE_DESCRIPTION[1])
end

function _hookWifiConnect(mac, dev)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local mackey = mac:gsub(":", "")
    local notify, timestamp = XQPushUtil.specialNotify(mac)
    local settings = XQPushUtil.pushSettings()
    local uci = require("luci.model.uci").cursor()
    local unknown = uci:get("devicelist", "history", mackey) == nil and true or false
    local guest = uci:get("misc", "wireless", "guest_2G") or ""

    if unknown then
        uci:set("devicelist", "history", mackey, 1)
        uci:commit("devicelist")
    end
    XQPushUtil.setAuthenFailedTimes(mac, 0)
    local currenttime = tonumber(os.time())
    if notify then
        if currenttime - timestamp > PUSH_INTERVAL then
            notify = true
            XQPushUtil.setSpecialNotify(mac, true, currenttime)
        else
            notify = false
        end
    end

    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local deviceinfo = XQDeviceUtil.getDeviceInfo(mac)

    if (unknown or notify) and XQFunction.isStrNil(deviceinfo.dhcpname) then
        os.execute("sleep 5")
        deviceinfo = XQDeviceUtil.getDeviceInfo(mac)
    end

    if (unknown or notify) and not XQFunction.isStrNil(deviceinfo.dhcpname) then
        local dhcpname = string.lower(deviceinfo.dhcpname)
        if dhcpname:match("^miwifi%-r1c") then
            local payload = {
                ["type"] = 23,
                ["name"] = "小米路由器mini"
            }
            _doPush(Json.encode(payload), "中继成功", "中继成功")
            return
        elseif dhcpname:match("^miwifi%-r1d") or dhcpname:match("^miwifi%-r2d") then
            local payload = {
                ["type"] = 23,
                ["name"] = "小米路由器"
            }
            _doPush(Json.encode(payload), "中继成功", "中继成功")
            return
        end
    end

    if unknown or notify then
        local name = deviceinfo.name
        if name and string.lower(name):match("android-%S+") and #name > 12 then
            name = name:sub(1, 12)
        end
        if (deviceinfo["type"].c == 2 and deviceinfo["type"].p == 6)
            or (deviceinfo["type"].c == 3 and deviceinfo["type"].p == 2)
            or (deviceinfo["type"].c == 3 and deviceinfo["type"].p == 7) then
            return
        end
        if unknown and settings.auth then
            local payload = {
                ["type"] = 3,
                ["mac"] = mac,
                ["name"] = name
            }
            if dev == guest then
                payload["type"] = 27
            end
            _doPush(Json.encode(payload), PUSH_MESSAGE_TITLE[3], PUSH_MESSAGE_DESCRIPTION[3])
            if deviceinfo.flag == 0 then
                XQDBUtil.saveDeviceInfo(mac,deviceinfo.dhcpname,"","","")
            end
            XQLog.log(6, "New/Guest Device Connect.", deviceinfo)
        elseif notify then
            local payload = {
                ["type"] = 28,
                ["mac"] = mac,
                ["name"] = name
            }
            _doPush(Json.encode(payload), "指定设备上线", "指定设备上线")
            XQLog.log(6, "Special Device Connect.", deviceinfo)
        end
    end
end

function _hookWifiDisconnect(mac)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    XQLog.log(6, "Device Disconnet:"..mac)
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local count = #XQWifiUtil.getWifiConnectDeviceList(1) + #XQWifiUtil.getWifiConnectDeviceList(2)
    if count == 0 and not WIFI_CLEAR then
        local payload = {
            ["type"] = 4
        }
        _doPush(Json.encode(payload), PUSH_MESSAGE_TITLE[4], PUSH_MESSAGE_DESCRIPTION[4])
        XQLog.log(6, "WiFi clear")
        WIFI_CLEAR = true
    end
end

function _hookAllDownloadFinished()
    XQLog.log(6, "All download finished")
    local payload = {
        ["type"] = 5
    }
    _doPush(Json.encode(payload), PUSH_MESSAGE_TITLE[5], PUSH_MESSAGE_DESCRIPTION[5])
end

function _hookIntelligentScene(name,actions)
    local sname = name
    if XQFunction.isStrNil(sname) then
        sname = ""
    end
    XQLog.log(6, "Intelligent Scene:"..name.." finished!")
    local payload = {
        ["type"] = 6,
        ["name"] = name,
        ["actions"] = actions
    }
    _doPush(Json.encode(payload), PUSH_MESSAGE_TITLE[6], PUSH_MESSAGE_DESCRIPTION[6])
end

function _hookDetectFinished(lan, wan)
    if lan and wan then
        XQLog.log(6, "network detect finished!")
        local payload = {
            ["type"] = 7,
            ["lan"] = lan,
            ["wan"] = wan
        }
        _doPush(Json.encode(payload), PUSH_MESSAGE_TITLE[7], PUSH_MESSAGE_DESCRIPTION[7])
    end
end

function _hookCachecenterEvent(hitcount, timesaver)
    if hitcount and timesaver then
        XQLog.log(6, "cachecenter event!")
        local payload = {
            ["type"] = 13,
            ["hitcount"] = hitcount,
            ["timesaver"] = timesaver
        }
        _doPush(Json.encode(payload), PUSH_MESSAGE_TITLE[8], PUSH_MESSAGE_DESCRIPTION[8])
    end
end

function _hookDownloadEvent(count)
    if tonumber(count) then
        XQLog.log(6, "download event!")
        local payload = {
            ["type"] = 17,
            ["count"] = tonumber(count)
        }
        _doPush(Json.encode(payload), "下载完成", "下载完成")
    end
end

function _hookUploadEvent(count)
    if tonumber(count) then
        XQLog.log(6, "upload event!")
        local payload = {
            ["type"] = 18,
            ["count"] = tonumber(count)
        }
        _doPush(Json.encode(payload), "上传完成", "上传完成")
    end
end

function _hookADFilterEvent(page, all)
    if tonumber(page) and tonumber(all) then
        XQLog.log(6, "upload event!")
        local payload = {
            ["type"] = 19,
            ["page"] = tonumber(page),
            ["all"] = tonumber(all)
        }
        _doPush(Json.encode(payload), "广告过滤", "广告过滤")
    end
end

function _hookWifiImprove(improve, wifi)
    local wifi = tonumber(wifi)
    if wifi == 1 then
        wifi = "2.4G"
    elseif wifi == 0 then
        wifi = "5G"
    else
        wifi = ""
    end
    if not XQFunction.isStrNil(improve) then
        XQLog.log(6, "wifi improve event!")
        local payload = {
            ["type"] = 25,
            ["improve"] = improve,
            ["wifi"] = wifi
        }
        _doPush(Json.encode(payload), "信道提升", "信道提升")
    end
end

function _hookDefault(data)
    XQLog.log(6, "Unknown Feed")
    local payload = {
        ["type"] = 999,
        ["data"] = data
    }
    _doPush(Json.encode(payload), PUSH_DEFAULT_MESSAGE_TITLE, PUSH_DEFAULT_MESSAGE_DESCRIPTION)
end

function _hookNewRomVersionDetected(version)
    XQLog.log(6, "New ROM version detected")
    local routerName = XQPreference.get(XQConfigs.PREF_ROUTER_NAME, "")
    local _romChannel = XQSysUtil.getChannel()
    local payload = {
        ["type"] = 14,
        ["name"] = routerName,
        ["version"] = version,
        ["channel"] = _romChannel
    }
    local title = string.format(PUSH_MESSAGE_TITLE[9], routerName)
    local romChannel = "开发版"
    if _romChannel == "current" then
        romChannel = "内测版"
    end
    if _romChannel == "release" then
        romChannel = "稳定版"
    end
    local description = string.format(PUSH_MESSAGE_DESCRIPTION[9], version, romChannel)
    _doPush(Json.encode(payload), title, description)
end

function _hookWifiImproveNotify()
    local payload = {
        ["type"] = 29
    }
    _doPush(Json.encode(payload), "信道可以优化", "信道可以优化")
end

function _hookWifiAuthenFailed(mac)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local mackey = mac:gsub(":", "")
    local settings = XQPushUtil.pushSettings()
    local times = XQPushUtil.getAuthenFailedTimes(mac)
    if settings.auth then
        local cache = XQCacheUtil.getCache(mackey)
        if cache then
            return
        else
            times = times + 1
            if times ~= 0 and math.mod(times, 5) == 0 then
                if settings.quiet then
                    local hour = os.date("%H", os.time())
                    if hour > 21 or hour < 8 then
                        return
                    end
                end
                XQPushUtil.setAuthenFailedTimes(mac, times)
                local payload = {
                    ["type"] = 30,
                    ["mac"] = mac
                }
                _doPush(Json.encode(payload), "WiFi密码错误", "WiFi密码错误")
                return
            end
            XQCacheUtil.saveCache(mackey, mackey, 5)
            XQPushUtil.setAuthenFailedTimes(mac, times)
        end
    end
end

function _hookWifiBlacklisted(mac)
    if XQFunction.isStrNil(mac) then
        return
    else
        mac = XQFunction.macFormat(mac)
    end
    local mackey = mac:gsub(":", "")
    local settings = XQPushUtil.pushSettings()
    local times = XQPushUtil.getAuthenFailedTimes(mac)
    if settings.auth then
        local cachekey = mackey.."_black"
        local cache = XQCacheUtil.getCache(cachekey)
        if cache then
            return
        else
            times = times + 1
            XQCacheUtil.saveCache(mackey, mackey, 2)
            XQPushUtil.setAuthenFailedTimes(mac, times)
        end
    end
end

function push_request_lua(payload)
    local ptype = tonumber(payload.type)
    if ptype == 1 then
        _hookWifiConnect(payload.data.mac, payload.data.dev)
    elseif ptype == 2 then
        _hookWifiDisconnect(payload.data.mac)
    elseif ptype == 3 then
        _hookSysUpgraded()
    elseif ptype == 4 then
        _hookAllDownloadFinished()
    elseif ptype == 5 then
        _hookIntelligentScene(payload.data.name,payload.data.list)
    elseif ptype == 6 then
        _hookDetectFinished(payload.data.lan, payload.data.wan)
    elseif ptype == 7 then
        _hookCachecenterEvent(payload.data.hit_count, payload.data.timesaver)
    elseif ptype == 8 then
        _hookNewRomVersionDetected(payload.data.version)
    elseif ptype == 9 then
        _hookDownloadEvent(payload.data.count)
    elseif ptype == 10 then
        _hookUploadEvent(payload.data.count)
    elseif ptype == 11 then
        _hookADFilterEvent(payload.data.filter_page, payload.data.filter_all)
    elseif ptype == 12 then
        _hookWifiImprove(payload.data.improve, payload.data.wifi)
    elseif ptype == 13 then
        _hookWifiImproveNotify()
    elseif ptype == 14 then
        _hookWifiAuthenFailed(payload.data.mac)
    elseif ptype == 15 then
        _hookWifiBlacklisted(payload.data.mac)
    else
        _hookDefault(payload.data)
    end
    return true
end

--
-- type:{1,2,3...}
-- data:{...}
--
function push_request(payload)
    if XQFunction.isStrNil(payload) then
        return false
    end
    XQLog.log(6,"Push request:",payload)
    local payload = Json.decode(payload)
    return push_request_lua(payload)
end