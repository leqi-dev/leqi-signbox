module("luci.controller.api.OKnetwork", package.seeall)
local LuciHttp = require("luci.http")

function index()
    	local page   = node("api","OKnetwork")
    	page.target  = firstchild()
    	page.title   = ("")
    	page.order   = 100
    	page.sysauth = "root"
    	page.sysauth_authenticator = "noauth"
    	page.index = true	
	entry({"api", "OKnetwork"}, firstchild(), (""), 100);
	entry({"api", "OKnetwork", "wifi_list"}, call("getScanList"), (""), 183)
	entry({"api", "OKnetwork", "set_wifi_ap"}, call("setWifiApMode"), (""), 266)
	entry({"api", "OKnetwork", "wan_link"}, call("getWanLinkStatus"), (""), 265)
	entry({"api", "OKnetwork", "check_wan_type"}, call("getAutoWanType"), (""), 218)
	entry({"api", "OKnetwork", "wan_info"}, call("getWanInfo"), (""), 214)
	entry({"api", "OKnetwork", "pppoe_status"}, call("pppoeStatus"), (""), 236)
    	entry({"api", "OKnetwork", "pppoe_stop"}, call("pppoeStop"), (""), 237)
    	entry({"api", "OKnetwork", "pppoe_start"}, call("pppoeStart"), (""), 238)
	entry({"api", "OKnetwork", "set_wan"}, call("setWan"), (""), 223)
end

function setWan()
    local OKLog = require("officekit.OKLog")
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local OKFunction = require("officekit.common.OKFunction")
    local code = 0
    local result = {}
    local client = LuciHttp.formvalue("client")
    local wanType = LuciHttp.formvalue("wanType")
    local pppoeName = LuciHttp.formvalue("pppoeName")
    local pppoePwd = LuciHttp.formvalue("pppoePwd")
    local staticIp = LuciHttp.formvalue("staticIp")
    local staticMask = LuciHttp.formvalue("staticMask")
    local staticGateway = LuciHttp.formvalue("staticGateway")
    local dns1 = LuciHttp.formvalue("dns1")
    local dns2 = LuciHttp.formvalue("dns2")
    local special = LuciHttp.formvalue("special") or 0
    local peerDns = LuciHttp.formvalue("peerDns")
    local mtu = tonumber(LuciHttp.formvalue("mtu"))
    local service = LuciHttp.formvalue("service")
    if OKFunction.isStrNil(wanType)
        and OKFunction.isStrNil(pppoeName)
        and OKFunction.isStrNil(pppoePwd)
        and OKFunction.isStrNil(staticIp)
        and OKFunction.isStrNil(staticMask)
        and OKFunction.isStrNil(staticGateway)
        and OKFunction.isStrNil(dns1)
        and OKFunction.isStrNil(dns2)
        and OKFunction.isStrNil(special)
        and OKFunction.isStrNil(peerDns) then
            code = 1502
    else
        OKLog.check(0, OKLog.KEY_FUNC_WAN_METHOD, wanType)
        if wanType == "pppoe" then
            if client == "web" then
                OKLog.check(0, OKLog.KEY_VALUE_NETWORK_PPPOE, 1)
                OKLog.check(0, OKLog.KEY_FUNC_WAN_PPPOE, 1)
            end
            if OKFunction.isStrNil(pppoeName) or OKFunction.isStrNil(pppoePwd) then
                code = 1528
            else
                if mtu and not OKLanWanUtil.checkMTU(mtu) then
                    code = 1590
                else
                    if not OKLanWanUtil.setWanPPPoE(pppoeName, pppoePwd, dns1, dns2, peerDns, mtu, special, service) then
                        code = 1529
                    end
                end
            end
        elseif wanType == "dhcp" then
            if client == "web" then
                OKLog.check(0, OKLog.KEY_VALUE_NETWORK_DHCP, 1)
                OKLog.check(0, OKLog.KEY_FUNC_WAN_DHCP, 1)
            end
            if not OKLanWanUtil.setWanStaticOrDHCP(wanType, nil, nil, nil, dns1, dns2, peerDns, mtu) then
                code = 1529
            end
        elseif wanType == "static" then
            if client == "web" then
                OKLog.check(0, OKLog.KEY_VALUE_NETWORK_STATIC, 1)
                OKLog.check(0, OKLog.KEY_FUNC_WAN_IP, 1)
            end
            local LuciDatatypes = require("luci.cbi.datatypes")
            local LuciIp = require("luci.ip")
            if not LuciDatatypes.ipaddr(staticIp) then
                code = 1530
            elseif not OKFunction.checkMask(staticMask) then
                code = 1531
            elseif not LuciDatatypes.ipaddr(staticGateway) then
                code = 1532
            else
                local lanIp = OKLanWanUtil.getLanWanIp("lan")[1]
                local lanIpNl = LuciIp.iptonl(lanIp.ip)
                local lanMaskNl = LuciIp.iptonl(lanIp.mask)
                local wanIpNl = LuciIp.iptonl(staticIp)
                local wanMaskNl = LuciIp.iptonl(staticMask)
                if bit.band(lanIpNl,lanMaskNl) == bit.band(wanIpNl,lanMaskNl) or bit.band(lanIpNl,wanMaskNl) == bit.band(wanIpNl,wanMaskNl) then
                    code = 1526
                else
                    code = OKLanWanUtil.checkWanIp(staticIp)
                    if code == 0 then
                        if not OKLanWanUtil.setWanStaticOrDHCP(wanType, staticIp, staticMask, staticGateway, dns1, dns2, peerDns, mtu) then
                            code = 1529
                        end
                    end
                end
            end
        else
            -- unknown type
        end
    end
    result["code"] = code
    if code ~= 0 then
       result["msg"] = OKErrorUtil.getErrorMessage(code)
    end
    LuciHttp.write_json(result)
end

function getWanInfo()
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local wan = OKLanWanUtil.getLanWanInfo("wan")
    local result = {}
    result["code"] = 0
    result["info"] = wan
    LuciHttp.write_json(result)
end

function getWanLinkStatus()
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local result = {
        ["code"] = 0,
        ["link"] = 0
    }
    if OKLanWanUtil.getWanLink() then
        result.link = 1
    end
    LuciHttp.write_json(result)
end

function getAutoWanType()
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local OKPreference = require("officekit.OKPreference")
    local OKConfigs = require("officekit.common.OKConfigs")
    local result = {}
    local code = 0
    local wanType = OKLanWanUtil.getAutoWanType()
    if wanType == false then
        code = 1524
    else
        result["wanType"] = wanType
        result["pppoeName"] = OKPreference.get(OKConfigs.PREF_PPPOE_NAME, "")
        result["pppoePassword"] = OKPreference.get(OKConfigs.PREF_PPPOE_PASSWORD, "")
    end
    if code ~= 0 then
       result["msg"] = OKErrorUtil.getErrorMessage(code)
    end
    result["code"] = code
    LuciHttp.write_json(result)
end

function setWifiApMode()
    local OKLog = require("officekit.OKLog")
    local OKFunction = require("officekit.common.OKFunction")
    local OKAPModule = require("officekit.module.OKAPModule")
    local OKSysUtil = require("officekit.util.OKSysUtil")
    local OKWifiUtil = require("officekit.util.OKWifiUtil")
    local OKErrorUtil = require("officekit.util.OKErrorUtil")
    local log = require "luci.log"
    local result = {
        ["code"] = 0
    }

    local ssid = LuciHttp.formvalue("ssid")
    local encryption = LuciHttp.formvalue("encryption")
    local enctype = LuciHttp.formvalue("enctype")
    local password = LuciHttp.formvalue("password")
    local channel = LuciHttp.formvalue("channel")
    local bandwidth = LuciHttp.formvalue("bandwidth")
    local nssid = LuciHttp.formvalue("nssid")
    local nencryption = LuciHttp.formvalue("nencryption")
    local npassword = LuciHttp.formvalue("npassword")
    local initialize = tonumber(LuciHttp.formvalue("initialize")) == 1 and 1 or 0
    local nonce = LuciHttp.formvalue("nonce")
    local newPwd = LuciHttp.formvalue("newPwd")
    local oldPwd = LuciHttp.formvalue("oldPwd")

    OKLog.check(0, OKLog.KEY_WIFI_AP, 1)
    OKLog.check(0, OKLog.KEY_FUNC_WIFI_RELAY, 1)
    if ssid and (password or encryption == "NONE") then
        local ap = OKAPModule.setWifiAPMode(ssid, encryption, enctype, password, channel, bandwidth, nssid, nencryption, npassword)
        if not ap.scan then
            result.code = 1617
        elseif ap.connected then
            if OKFunction.isStrNil(ap.ip) then
                result.code = 1615
            else
                result.ip = ap.ip
                result.ssid = ap.ssid
            end
        else
            result.code = 1616
            result["msg"] = OKErrorUtil.getErrorMessage(result.code).."("..tostring(ap.conerrmsg)..")"
        end
    else
        result.code = 1523
    end
    if result.code ~= 0 and result.code ~= 1616 then
        result["msg"] = OKErrorUtil.getErrorMessage(result.code)
    elseif result.code == 0 then
        if initialize == 1 and ssid then
            OKSysUtil.setRouterName(ssid)
            if nonce and newPwd and oldPwd then
                result.code = _savePassword(nonce, oldPwd, newPwd)
                OKSysUtil.setSPwd()
            end
        end
        OKSysUtil.setInited()
        OKAPModule.serviceRestart()
    end
    LuciHttp.write_json(result)
end

function pppoeStatus()
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local code = 0
    local result = {}
    local status = OKLanWanUtil.getPPPoEStatus()
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
            result["msg"] = string.format("%s(%s)",OKErrorUtil.getErrorMessage(code), tostring(result.errcode))
        else
            result["msg"] = OKErrorUtil.getErrorMessage(code)
        end
    end
    result["code"] = code
    LuciHttp.write_json(result)
end

function pppoeStop()
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local result = {
        ["code"] = 0
    }
    OKLanWanUtil.pppoeStop()
    LuciHttp.write_json(result)
end

function pppoeStart()
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local result = {
        ["code"] = 0
    }
    OKLanWanUtil.pppoeStart()
    LuciHttp.write_json(result)
end


function getScanList()                                                        
    local OKWifiUtil = require("officekit.util.OKWifiUtil")                          
    local result = {                                                                     
        ["code"] = 0                                                                 
    }                                                                                       
    --result["list"] = scanlist(3);    
    result["list"] = OKWifiUtil.getWifiScanlist();                         
    LuciHttp.write_json(result)                                                     
end

local iw = luci.sys.wifi.getiwinfo("radio0")

        function scanlist(times)                                                                  
                local i, k, v                                                                     
                local l = { }                                                                     
                local s = { }                                                                     
                                                                                                  
                for i = 1, times do                                                               
                        for k, v in ipairs(iw.scanlist or { }) do                                 
                                if not s[v.bssid] then                                            
                                        l[#l+1] = v                                               
                                        s[v.bssid] = true                                         
                                end                                                               
                        end                                                                       
                end                                                                               
                                                                                                  
                return l                                                                          
        end
