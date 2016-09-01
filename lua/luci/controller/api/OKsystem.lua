module("luci.controller.api.OKsystem", package.seeall)
local LuciHttp = require("luci.http")
local OKSysUtil = require("officekit.util.OKSysUtil")
local OKErrorUtil = require("officekit.util.OKErrorUtil")

function index()
    	local page   = node("api","OKsystem")
    	page.target  = firstchild()
    	page.title   = ("")
    	page.order   = 100
    	page.sysauth = "root"
    	page.sysauth_authenticator = "jsonauth"
    	page.index = true	
	entry({"api", "OKsystem"}, firstchild(), (""), 100);
	entry({"api", "OKsystem", "set_privacy"}, call("setPrivacy"), (""), 183)
	entry({"api", "OKsystem", "login"}, call("actionLogin"), (""), 109, false, 0x01)
	entry({"api", "OKsystem", "set_inited"}, call("setInited"), (""), 103, false, 0x01)
	entry({"api", "OKsystem", "router_init"}, call("setRouter"), (""), 126)
end

function setInited()
    local OKLog = require("officekit.OKLog")
    local client = LuciHttp.formvalue("client")
    if client == "ios" then
        OKLog.check(0, OKLog.KEY_GEL_INIT_IOS, 1)
    elseif client == "android" then
        OKLog.check(0, OKLog.KEY_GEL_INIT_ANDROID, 1)
    elseif client == "other" then
        OKLog.check(0, OKLog.KEY_GEL_INIT_OTHER, 1)
    end
    local result = {}
    local inited = OKSysUtil.setInited()
    if not inited then
        result["code"] = 1501
        result["msg"] = OKErrorUtil.getErrorMessage(1501)
    else
        result["code"] = 0
    end
    LuciHttp.write_json(result)
end

function _savePassword(nonce, oldpwd, newpwd)
    local OKSecureUtil = require("officekit.util.OKSecureUtil")
    local code = 0
    local mac = luci.dispatcher.getremotemac()
    local checkNonce = OKSecureUtil.checkNonce(nonce, mac)
    if checkNonce then
        local check = OKSecureUtil.checkUser("root", nonce, oldpwd)
        if check then
            if OKSecureUtil.saveCiphertextPwd("root", newpwd) then
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

function setRouter()
local log = require "luci.log"
    local OKConfigs = require("officekit.common.OKConfigs")
    local OKFunction = require("officekit.common.OKFunction")
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local OKWifiUtil = require("officekit.util.OKWifiUtil")
    local result = {}
    local code = 0
    local msg = {}
    local needRestartWifi = false
    local nonce = LuciHttp.formvalue("nonce")
    local newPwd = LuciHttp.formvalue("newPwd")
    local oldPwd = LuciHttp.formvalue("oldPwd")
    local wifiPwd = LuciHttp.formvalue("wifiPwd")
    local wifi24Ssid = LuciHttp.formvalue("wifi24Ssid")
    local wifi50Ssid = LuciHttp.formvalue("wifi50Ssid")
    local wanType = LuciHttp.formvalue("wanType")
    local pppoeName = LuciHttp.formvalue("pppoeName")
    local pppoePwd = LuciHttp.formvalue("pppoePwd")
    local checkssid = OKWifiUtil.checkSSID(wifi24Ssid,28)
    if not OKFunction.isStrNil(wifi24Ssid) and checkssid == 0 then
        OKSysUtil.setRouterName(wifi24Ssid)
    end
    if not OKFunction.isStrNil(newPwd) and not OKFunction.isStrNil(oldPwd) then
        if nonce then
            code = _savePassword(nonce, oldPwd, newPwd)
        else
            local check = OKSysUtil.checkSysPassword(oldPwd)
            if check then
                local succeed = OKSysUtil.setSysPassword(newPwd)
                if not succeed then
                    code = 1515
                end
            else
                code = 1552
            end
        end
        if code ~= 0 then
            table.insert(msg,OKErrorUtil.getErrorMessage(code))
        end
    end
    if not OKFunction.isStrNil(wanType) then
        local succeed
        if wanType == "pppoe" and not OKFunction.isStrNil(pppoeName) and not OKFunction.isStrNil(pppoePwd) then
            succeed = OKLanWanUtil.setWanPPPoE(pppoeName,pppoePwd)
        elseif wanType == "dhcp" then
            succeed = OKLanWanUtil.setWanStaticOrDHCP(wanType)
        end
        if not succeed then
            code = 1518
            table.insert(msg,OKErrorUtil.getErrorMessage(code))
        else
            needRestartWifi = true
        end
    end
    if not OKFunction.isStrNil(wifiPwd) and checkssid == 0 then
        local succeed1 = OKWifiUtil.setWifiBasicInfo(1, wifi24Ssid, wifiPwd, "mixed-psk", nil, nil, 0)
        local succeed2 = OKWifiUtil.setWifiBasicInfo(2, wifi50Ssid, wifiPwd, "mixed-psk", nil, nil, 0)
        if succeed1 or succeed2 then
            needRestartWifi = true
        end
        if not succeed1 or not succeed2 then
            code = OKWifiUtil.checkWifiPasswd(wifiPwd, "mixed-psk")
            table.insert(msg,OKErrorUtil.getErrorMessage(code))
        end
    end
    if checkssid ~= 0 then
        code = checkssid
    end
    if code ~= 0 then
        result["msg"] = OKErrorUtil.getErrorMessage(1519)
        result["errorDetails"] = msg
    end
    OKSysUtil.setSPwd()
    OKSysUtil.setInited()
    result["code"] = code
    LuciHttp.write_json(result)
    if needRestartWifi then
        LuciHttp.close()
        OKFunction.forkRestartWifi(true)
    end
end

function setPrivacy()        
local log = require "luci.log"
    local result = {                                                                                  
        ["code"] = 0,                                                                                 
    }                                                                                                 
    LuciHttp.write_json(result)                                                                       
end

function actionLogin()                                                                 
    local OKLog = require("officekit.OKLog")                                           
    local result = {}                                                                  
    local init = tonumber(LuciHttp.formvalue("init"))                                  
    local privacy = tonumber(LuciHttp.formvalue("privacy"))                                                                   
    result["code"] = 0                                                                 
    if init and init == 1 then                                                                                             
        --local OKSysUtil = require("officekit.util.OKSysUtil")                          
        --OKSysUtil.setPrivacy(privacy == 1 and true or false)                           
        result["url"] = luci.dispatcher.build_url("okweb", "init", "guide")              
    else                                                                               
        OKLog.check(0, OKLog.KEY_GEL_USE, 1)                                           
        result["url"] = luci.dispatcher.build_url("okweb", "setting","wan")                       
    end                                                                                
    LuciHttp.write_json(result)                                                        
end
