module("luci.controller.api.misystem", package.seeall)

function index()
    local page   = node("api","xqsystem")
    page.target  = firstchild()
    page.title   = ("")
    page.order   = 100
    page.sysauth = "admin"
    page.sysauth_authenticator = "jsonauth"
    page.index = true
    entry({"api", "misystem"}, firstchild(), (""), 100)
    entry({"api", "misystem", "status"}, call("mainStatus"), (""), 101)
    entry({"api", "misystem", "devicelist"}, call("getDeviceList"), (""), 102)
    entry({"api", "misystem", "messages"}, call("getMessages"), (""), 103)

    entry({"api", "misystem", "router_name"}, call("getRouterName"), (""), 104, 0x08)
    entry({"api", "misystem", "set_router_name"}, call("setRouterName"), (""), 105, 0x08)
    entry({"api", "misystem", "set_router_wifiap"}, call("setWifiApMode"), (""), 106, 0x08)
    entry({"api", "misystem", "set_router_lanap"}, call("setLanApMode"), (""), 106, 0x08)
    entry({"api", "misystem", "set_router_normal"}, call("setRouterInfo"), (""), 107, 0x08)
    entry({"api", "misystem", "set_wan"}, call("setWan"), (""), 107, 0x08)
    entry({"api", "misystem", "pppoe_status"}, call("getPPPoEStatus"), (""), 107, 0x08)
    entry({"api", "misystem", "pppoe_stop"}, call("pppoeStop"), (""), 107, 0x08)
    entry({"api", "misystem", "ota"}, call("getOTAInfo"), (""), 108, 0x08)
    entry({"api", "misystem", "set_ota"}, call("setOTAInfo"), (""), 109, 0x08)

    entry({"api", "misystem", "device_detail"}, call("getDeviceDetail"), (""), 110)
    entry({"api", "misystem", "device_info"}, call("getDeviceInfo"), (""), 111, 0x08)
    entry({"api", "misystem", "channel_scan_start"}, call("channelScanStart"), (""), 111)
    entry({"api", "misystem", "channel_scan_result"}, call("getScanResult"), (""), 112)
    entry({"api", "misystem", "set_channel"}, call("setChannel"), (""), 113)

    entry({"api", "misystem", "topo_graph"}, call("getTopoGraph"), (""), 114)
    entry({"api", "misystem", "bandwidth_test"}, call("bandwidthTest"), (""), 115)
    entry({"api", "misystem", "router_common_status"}, call("getRouterStatus"), (""), 116)

    entry({"api", "misystem", "qos_info"}, call("getQosInfo"), (""), 117)
    entry({"api", "misystem", "qos_switch"}, call("qosSwitch"), (""), 118)
    entry({"api", "misystem", "qos_mode"}, call("qosMode"), (""), 119)
    entry({"api", "misystem", "qos_limit"}, call("qosLimit"), (""), 120)
    entry({"api", "misystem", "qos_limits"}, call("qosLimits"), (""), 121)
    entry({"api", "misystem", "qos_offlimit"}, call("qosOffLimit"), (""), 122)
    entry({"api", "misystem", "set_band"}, call("setBand"), (""), 123)
    entry({"api", "misystem", "qos_info_new"}, call("getQos"), (""), 129)

    entry({"api", "misystem", "active"}, call("active"), (""), 123)
    entry({"api", "misystem", "disk_repair"}, call("diskRepair"), (""), 124)
    entry({"api", "misystem", "repair_status"}, call("diskRepairStatus"), (""), 125)
    entry({"api", "misystem", "log_upload"}, call("syslogUpload"), (""), 126)
end

local LuciHttp = require("luci.http")
local LuciDatatypes = require("luci.cbi.datatypes")
local XQConfigs = require("xiaoqiang.common.XQConfigs")
local XQFunction = require("xiaoqiang.common.XQFunction")
local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
local XQErrorUtil = require("xiaoqiang.util.XQErrorUtil")

function active()
    local XQPreference = require("xiaoqiang.XQPreference")
    local result = {
        ["code"] = 0
    }
    local bandwidth = XQPreference.get("BANDWIDTH")
    if not bandwidth then
        os.execute("/etc/init.d/miqos stop")
        local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
        local uspeed, dspeed = XQNSTUtil.speedTest()
        if uspeed and dspeed then
            local download = tonumber(string.format("%.2f", 8 * dspeed/1024))
            local upload = tonumber(string.format("%.2f", 8 * uspeed/1024))
            XQPreference.set("BANDWIDTH", string.format("%.2f", 8 * dspeed/1024), "xiaoqiang")
            XQPreference.set("BANDWIDTH2", string.format("%.2f", 8 * uspeed/1024), "xiaoqiang")
            XQQoSUtil.setQosBand(upload, download)
        end
        os.execute("/etc/init.d/miqos start")
    end
    LuciHttp.write_json(result)
end

function mainStatus()
    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local result = {}
    local devStatList = XQDeviceUtil.getDevNetStatisticsList() or {}
    if #devStatList > 0 then
        table.sort(devStatList, function(a, b) return tonumber(a.download) > tonumber(b.download) end)
    end
    if #devStatList > XQConfigs.DEVICE_STATISTICS_LIST_LIMIT then
        local item = {}
        item["mac"] = ""
        item["ip"] = ""
        for i=1, #devStatList - XQConfigs.DEVICE_STATISTICS_LIST_LIMIT + 1 do
            local deleteElement = table.remove(devStatList, XQConfigs.DEVICE_STATISTICS_LIST_LIMIT)
            item["upload"] = tonumber(deleteElement.upload) + tonumber(item.upload or 0)
            item["upspeed"] = tonumber(deleteElement.upspeed) + tonumber(item.upspeed or 0)
            item["download"] = tonumber(deleteElement.download) + tonumber(item.download or 0)
            item["downspeed"] = tonumber(deleteElement.downspeed) + tonumber(item.downspeed or 0)
            item["online"] = deleteElement.online
            item["devname"] = "Others"
            item["maxuploadspeed"] = deleteElement.maxuploadspeed
            item["maxdownloadspeed"] = deleteElement.maxdownloadspeed
        end
        table.insert(devStatList,item)
    end
    local count = {
        ["online"] = 0,
        ["all"] = 0
    }
    count.online ,count.all = XQDeviceUtil.getDeviceCount()
    local sys = XQSysUtil.getSysInfo()
    local cpu = {
        ["core"] = sys.core,
        ["hz"] = sys.hz,
        ["load"] = 1
    }
    local sysinfo = XQSysUtil.checkSystemStatus()
    cpu.load = sysinfo.cpu
    local mem = {
        ["total"] = sys.memTotal,
        ["type"] = "DDR3",
        ["hz"] = 1333,
        ["usage"] = sysinfo.mem
    }
    result["code"] = 0
    result["count"] = count
    result["upTime"] = XQSysUtil.getSysUptime()
    result["wan"] = XQDeviceUtil.getWanLanNetworkStatistics("wan")
    result["dev"] = devStatList
    result["cpu"] = cpu
    result["mem"] = mem
    result["temperature"] = sysinfo.tmp
    LuciHttp.write_json(result)
end

function getDeviceList()
    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local result = {
        ["code"] = 0
    }
    local online = tonumber(LuciHttp.formvalue("online")) or 1
    local withbrlan = tonumber(LuciHttp.formvalue("withbrlan")) or 1
    result["mac"] = luci.dispatcher.getremotemac()
    result["list"] = XQDeviceUtil.getDeviceListV2(online == 1, withbrlan == 1)
    LuciHttp.write_json(result)
end

function getDeviceDetail()
    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local result = {
        ["code"] = 0
    }
    local mac = LuciHttp.formvalue("mac")
    if not mac or not LuciDatatypes.macaddr(mac) then
        result.code = 1523
    else
        result["info"] = XQDeviceUtil.getDeviceInfo(mac, true)
    end
    if result.code ~= 0 then
       result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function getMessages()
    local XQMessageBox = require("xiaoqiang.module.XQMessageBox")
    local messages = XQMessageBox.getMessages()
    local result = {
        ["code"] = 0,
        ["count"] = #messages,
        ["messages"] = messages
    }
    LuciHttp.write_json(result)
end

function getRouterName()
    local result = {
        ["code"] = 0,
        ["name"] = XQSysUtil.getRouterName(),
        ["locale"] = XQSysUtil.getRouterLocale()
    }
    LuciHttp.write_json(result)
end

function setRouterName()
    local result = {
        ["code"] = 0
    }
    local name = LuciHttp.formvalue("name")
    local locale = LuciHttp.formvalue("locale")
    if not XQFunction.isStrNil(name) then
        if XQFunction.utfstrlen(name) > 30 then
            result.code = 1523
        else
            XQSysUtil.setRouterName(name)
        end
    end
    if locale then
        if XQFunction.utfstrlen(locale) > 15 then
            result.code = 1523
        else
            XQSysUtil.setRouterLocale(locale)
        end
    end
    if result.code ~= 0 then
       result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function _savePassword(nonce, oldpwd, newpwd)
    local XQSecureUtil = require("xiaoqiang.util.XQSecureUtil")
    local code = 0
    local mac = luci.dispatcher.getremotemac()
    local checkNonce = XQSecureUtil.checkNonce(nonce, mac)
    if checkNonce then
        local check = XQSecureUtil.checkUser("admin", nonce, oldpwd)
        if check then
            if XQSecureUtil.saveCiphertextPwd("admin", newpwd) then
                code = 0
            else
                code = 1553
            end
        else
            code = 1552
        end
    else
        code = 1582
    end
    return code
end

function setRouterInfo()
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local result = {
        ["code"] = 0
    }
    local name      = LuciHttp.formvalue("name")
    local locale    = LuciHttp.formvalue("locale")
    local nonce     = LuciHttp.formvalue("nonce")
    local newPwd    = LuciHttp.formvalue("newPwd")
    local oldPwd    = LuciHttp.formvalue("oldPwd")
    local ssid      = LuciHttp.formvalue("ssid")
    local password  = LuciHttp.formvalue("password")

    if XQFunction.isStrNil(name)
        or XQFunction.isStrNil(locale)
        or XQFunction.isStrNil(nonce)
        or XQFunction.isStrNil(newPwd)
        or XQFunction.isStrNil(oldPwd)
        or XQFunction.isStrNil(ssid)
        or XQFunction.isStrNil(password) then
        result.code = 1523
    else
        result.code = _savePassword(nonce, oldPwd, newPwd)
        if XQFunction.utfstrlen(name) > 30 or XQFunction.utfstrlen(locale) > 15 then
            result.code = 1523
        end
        if result.code == 0 then
            local checkssid = XQWifiUtil.checkSSID(ssid, 28)
            if checkssid == 0 then
                XQWifiUtil.setWifiBasicInfo(1, ssid, password, "mixed-psk", nil, nil, 0)
                XQWifiUtil.setWifiBasicInfo(2, ssid.."_5G", password, "mixed-psk", nil, nil, 0)
                XQSysUtil.setRouterName(name)
                XQSysUtil.setRouterLocale(locale)
            else
                result.code = checkssid
            end
        end
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    else
        XQSysUtil.setInited()
        XQSysUtil.setSPwd()
        XQFunction.forkRestartWifi()
    end
    LuciHttp.write_json(result)
end

function setWifiApMode()
    local XQAPModule = require("xiaoqiang.module.XQAPModule")
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local result = {
        ["code"] = 0
    }

    local ssid          = LuciHttp.formvalue("ssid")
    local name          = LuciHttp.formvalue("name")
    local locale        = LuciHttp.formvalue("locale")
    local encryption    = LuciHttp.formvalue("encryption")
    local enctype       = LuciHttp.formvalue("enctype")
    local password      = LuciHttp.formvalue("password")
    local channel       = LuciHttp.formvalue("channel")
    local bandwidth     = LuciHttp.formvalue("bandwidth")
    local nssid         = LuciHttp.formvalue("nssid")
    local nencryption   = LuciHttp.formvalue("nencryption")
    local npassword     = LuciHttp.formvalue("npassword")
    local initialize    = tonumber(LuciHttp.formvalue("initialize")) == 1 and 1 or 0
    local nonce         = LuciHttp.formvalue("nonce")
    local newPwd        = LuciHttp.formvalue("newPwd")
    local oldPwd        = LuciHttp.formvalue("oldPwd")

    if initialize == 1 and name and locale then
        XQSysUtil.setRouterName(name)
        XQSysUtil.setRouterLocale(locale)
        if nonce and newPwd and oldPwd then
            result.code = _savePassword(nonce, oldPwd, newPwd)
        end
    end

    if result.code == 0 and ssid and (password or encryption == "NONE") then
        local ap = XQAPModule.setWifiAPMode(ssid, encryption, enctype, password, channel, bandwidth, nssid, nencryption, npassword)
        if not ap.scan then
            result.code = 1617
        elseif ap.connected then
            if XQFunction.isStrNil(ap.ip) then
                result.code = 1615
            else
                result.ip = ap.ip
                result.ssid = ap.ssid
            end
        else
            result.code = 1616
            result["msg"] = XQErrorUtil.getErrorMessage(result.code).."("..tostring(ap.conerrmsg)..")"
        end
    else
        if result.code == 0 then
            result.code = 1523
        end
    end

    if result.code ~= 0 and result.code ~= 1616 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    elseif result.code == 0 then
        XQSysUtil.setInited()
        if initialize == 1 then
            XQSysUtil.setSPwd()
        end
        XQAPModule.serviceRestart()
    end
    LuciHttp.write_json(result)
end

function setLanApMode()
    local XQAPModule = require("xiaoqiang.module.XQAPModule")
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local result = {
        ["code"] = 0
    }

    local ssid      = LuciHttp.formvalue("ssid")
    local name      = LuciHttp.formvalue("name")
    local locale    = LuciHttp.formvalue("locale")
    local password  = LuciHttp.formvalue("password")
    local nonce     = LuciHttp.formvalue("nonce")
    local newPwd    = LuciHttp.formvalue("newPwd")
    local oldPwd    = LuciHttp.formvalue("oldPwd")
    local initialize = tonumber(LuciHttp.formvalue("initialize")) == 1 and 1 or 0

    local mode = XQFunction.getNetMode()
    if mode == "wifiapmode" then
        result.code = 1618
    else
        if initialize == 1 and name and locale and password then
            if nonce and newPwd and oldPwd then
                result.code = _savePassword(nonce, oldPwd, newPwd)
                if result.code == 0 then
                    local ip = XQAPModule.setLanAPMode()
                    if ip then
                        result["ip"] = ip
                        XQWifiUtil.setWifiBasicInfo(1, ssid, password, "mixed-psk", nil, nil, 0)
                        XQWifiUtil.setWifiBasicInfo(2, ssid.."_5G", password, "mixed-psk", nil, nil, 0)
                        XQSysUtil.setInited()
                        XQSysUtil.setSPwd()
                        XQSysUtil.setRouterName(name)
                        XQSysUtil.setRouterLocale(locale)
                    else
                        result.code = 1619
                    end
                end
            end
        end
    end

    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function getOTAInfo()
    local XQPredownload = require("xiaoqiang.module.XQPredownload")
    local result = {}
    local ota = XQPredownload.predownloadInfo()
    result["code"] = 0
    result["time"] = ota.time
    result["auto"] = ota.auto
    LuciHttp.write_json(result)
end

function setOTAInfo()
    local XQPredownload = require("xiaoqiang.module.XQPredownload")
    local result = {
        ["code"] = 0
    }
    local auto = tonumber(LuciHttp.formvalue("auto"))
    local time = tonumber(LuciHttp.formvalue("time"))
    XQPredownload.setPredownload(nil, auto, time)
    LuciHttp.write_json(result)
end

function getDeviceInfo()
    local XQSysUtil = require("xiaoqiang.util.XQSysUtil")
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local XQDeviceUtil = require("xiaoqiang.util.XQDeviceUtil")
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local info = XQDeviceUtil.devicesInfo()
    local bssid2, bssid5 = XQWifiUtil.getWifiBssid()
    local ssid2, ssid5 = XQWifiUtil.getWifissid()
    local laninfo = XQLanWanUtil.getLanWanInfo("lan")
    info["router_name"] = XQSysUtil.getRouterName()
    info["router_locale"] = tostring(XQSysUtil.getRouterLocale())
    info["work_mode"] = tostring(XQFunction.getNetModeType())
    info["ap_lan_ip"] = XQLanWanUtil.getLanIp()
    info["bssid_24G"] = bssid2 or ""
    info["bssid_5G"] = bssid5 or ""
    info["ssid_24G"] = ssid2 or ""
    info["ssid_5G"] = ssid5 or ""
    info["bssid_lan"] = laninfo.mac
    LuciHttp.write_json(info)
end

function channelScanStart()
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local result = {
        ["code"] = 0
    }
    XQWifiUtil.wifiChannelQuality()
    LuciHttp.write_json(result)
end

function getScanResult()
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local result = {
        ["code"] = 0
    }
    local wifiinfo = XQWifiUtil.getAllWifiInfo()
    if wifiinfo[1] and wifiinfo[1].status == "1" then
        result["2G"] = XQWifiUtil.scanWifiChannel(1)
    end
    if wifiinfo[2] and wifiinfo[2].status == "1" then
        result["5G"] = XQWifiUtil.scanWifiChannel(2)
    end
    local status = 0
    if result["2G"] and result["2G"].code ~= 0 then
        status = 1
    end
    if result["5G"] and result["5G"].code ~= 0 then
        status = 1
    end
    result["status"] = status
    LuciHttp.write_json(result)
end

function setChannel()
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local channel1 = LuciHttp.formvalue("channel1")
    local channel2 = LuciHttp.formvalue("channel2")
    local result = {
        ["code"] = 0
    }
    XQWifiUtil.iwprivSetChannel(channel1, channel2)
    LuciHttp.write_json(result)
end

function getTopoGraph()
    local XQTopology = require("xiaoqiang.module.XQTopology")
    local result = {
        ["code"] = 0
    }
    local graph = XQTopology.topologicalGraph()
    result["graph"] = graph
    result["show"] = graph.leafs and 1 or 0
    LuciHttp.write_json(result)
end

function bandwidthTest()
    local XQPreference = require("xiaoqiang.XQPreference")
    local XQNSTUtil = require("xiaoqiang.module.XQNetworkSpeedTest")
    local code = 0
    local result = {}
    local history = LuciHttp.formvalue("history")
    if history then
        result["bandwidth"] = tonumber(XQPreference.get("BANDWIDTH", 0, "xiaoqiang"))
        result["download"] = tonumber(string.format("%.2f", 128 * result.bandwidth))
        result["bandwidth2"] = tonumber(XQPreference.get("BANDWIDTH2", 0, "xiaoqiang"))
        result["upload"] = tonumber(string.format("%.2f", 128 * result.bandwidth2))
    else
        os.execute("/etc/init.d/miqos stop")
        local uspeed, dspeed = XQNSTUtil.speedTest()
        if uspeed and dspeed then
            result["upload"] = uspeed
            result["download"] = dspeed
            result["bandwidth2"] = tonumber(string.format("%.2f", 8 * uspeed/1024))
            result["bandwidth"] = tonumber(string.format("%.2f", 8 * dspeed/1024))
            XQPreference.set("BANDWIDTH", tostring(result.bandwidth), "xiaoqiang")
            XQPreference.set("BANDWIDTH2", tostring(result.bandwidth2), "xiaoqiang")
        else
            code = 1588
        end
        if code ~= 0 then
            result["msg"] = XQErrorUtil.getErrorMessage(code)
        end
        os.execute("/etc/init.d/miqos start")
    end
    result["code"] = code
    LuciHttp.write_json(result)
end

function setWan()
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local result = {
        ["code"] = 0
    }
    local proto = LuciHttp.formvalue("proto")
    local username = LuciHttp.formvalue("username")
    local password = LuciHttp.formvalue("password")
    local service = LuciHttp.formvalue("service")
    XQLanWanUtil.setWan(proto, username, password, service)
    LuciHttp.write_json(result)
end

function getPPPoEStatus()
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local code = 0
    local result = {}
    local status = XQLanWanUtil.getPPPoEStatus()
    if status then
        result = status
        if result.errtype == 1 then
            code = 1603
        elseif result.errtype == 2 then
            code = 1604
        elseif result.errtype == 3 then
            code = 1605
        end
    else
        code = 1602
    end
    if code ~= 0 then
        if code ~= 1602 then
            result["msg"] = string.format("%s(%s)",XQErrorUtil.getErrorMessage(code), tostring(result.errcode))
        else
            result["msg"] = XQErrorUtil.getErrorMessage(code)
        end
    end
    result["code"] = 0
    LuciHttp.write_json(result)
end

function pppoeStop()
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local result = {
        ["code"] = 0
    }
    XQLanWanUtil.pppoeStop()
    LuciHttp.write_json(result)
end

function getRouterStatus()
    local XQRouterStatus = require("xiaoqiang.module.XQRouterStatus")
    local keystr = LuciHttp.formvalue("keys")
    local result = XQRouterStatus.getStatus(keystr)
    result["code"] = 0
    LuciHttp.write_json(result)
end

function getQosInfo()
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local result = {
        ["code"] = 0
    }
    local band = XQQoSUtil.qosBand()
    local status = XQQoSUtil.qosStatus()
    local qoslist = XQQoSUtil.qosList()
    result["status"] = status
    result["list"] = qoslist
    result["band"] = band
    LuciHttp.write_json(result)
end

function getQos()
    local LuciUtil = require("luci.util")
    local XQFunction = require("xiaoqiang.common.XQFunction")
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local macs = LuciHttp.formvalue("macs")
    if not XQFunction.isStrNil(macs) then
        macs = LuciUtil.split(macs, ";")
    end
    local result = XQQoSUtil.qosHistory(macs)
    result["code"] = 0
    LuciHttp.write_json(result)
end

function qosSwitch()
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local result = {
        ["code"] = 0
    }
    local on = tonumber(LuciHttp.formvalue("on")) == 1 and true or false
    local switch = XQQoSUtil.qosSwitch(on)
    if not switch then
        result.code = 1606
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function qosMode()
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local result = {
        ["code"] = 0
    }
    local mode = tonumber(LuciHttp.formvalue("mode"))
    local status = XQQoSUtil.qosStatus()
    local setmode
    if status and status.on == 1 then
        setmode = XQQoSUtil.setQoSMode(mode)
    else
        result.code = 1607
    end
    if not setmode and result.code == 0 then
        result.code = 1606
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

-- upload/download M bits/s
function setBand()
    local XQPreference = require("xiaoqiang.XQPreference")
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local result = {
        ["code"] = 0
    }
    local upload = tonumber(LuciHttp.formvalue("upload"))
    local download = tonumber(LuciHttp.formvalue("download"))
    XQPreference.set("BANDWIDTH", tostring(download), "xiaoqiang")
    XQPreference.set("BANDWIDTH2", tostring(upload), "xiaoqiang")
    local band = XQQoSUtil.setQosBand(upload, download)
    if not band then
        result.code = 1606
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function qosLimit()
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local result = {
        ["code"] = 0
    }
    local mac      = LuciHttp.formvalue("mac")
    local mode = tonumber(LuciHttp.formvalue("mode")) or 0
    local upload   = tonumber(LuciHttp.formvalue("upload"))
    local download = tonumber(LuciHttp.formvalue("download"))
    local limit
    local status = XQQoSUtil.qosStatus()
    if status and status.on == 1 then
        if mac and mode and upload and download then
            limit = XQQoSUtil.qosOnLimit(mac, mode, upload, download)
        else
            result.code = 1523
        end
    else
        result.code = 1607
    end
    if not limit and result.code == 0 then
        result.code = 1606
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function qosLimits()
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local Json = require("luci.json")
    local mode = tonumber(LuciHttp.formvalue("mode")) or 0
    local data = LuciHttp.formvalue("data")
    local result = {
        ["code"] = 0
    }
    local limit
    if data then
        data = Json.decode(data)
    else
        result.code = 1523
    end
    local status = XQQoSUtil.qosStatus()
    if status and status.on == 1 then
        if mode and data then
            limit = XQQoSUtil.qosOnLimits(mode, data)
            if not limit then
                result.code = 1606
            end
        else
            result.code = 1523
        end
    else
        result.code = 1607
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function qosOffLimit()
    local XQQoSUtil = require("xiaoqiang.util.XQQoSUtil")
    local result = {
        ["code"] = 0
    }
    local mac = LuciHttp.formvalue("mac")
    local status = XQQoSUtil.qosStatus()
    local offlimit
    if status and status.on == 1 then
        offlimit = XQQoSUtil.qosOffLimit(mac)
    else
        result.code = 1607
    end
    if not offlimit and result.code == 0 then
        result.code = 1606
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function diskRepair()
    local XQDisk = require("xiaoqiang.module.XQDisk")
    local result = {
        ["code"] = 0
    }
    if not XQDisk.diskrepair() then
        result.code = 1622
    end
    if result.code ~= 0 then
        result["msg"] = XQErrorUtil.getErrorMessage(result.code)
    end
    LuciHttp.write_json(result)
end

function diskRepairStatus()
    local XQDisk = require("xiaoqiang.module.XQDisk")
    local result = {
        ["code"] = 0,
        ["status"] = XQDisk.repairstatus()
    }
    LuciHttp.write_json(result)
end

function syslogUpload()
    local XQFunction = require("xiaoqiang.common.XQFunction")
    local XQNetUtil = require("xiaoqiang.util.XQNetUtil")
    local key = XQNetUtil.generateLogKey()
    local result = {
        ["code"] = 0,
        ["key"]  = key
    }
    XQFunction.forkExec("lua /usr/sbin/syslog_upload.lua "..key)
    LuciHttp.write_json(result)
end
