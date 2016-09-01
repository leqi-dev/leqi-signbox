module ("officekit.module.OKAPModule", package.seeall)

local OKFunction = require("officekit.common.OKFunction")
local OKConfigs = require("officekit.common.OKConfigs")
local LuciUtil = require("luci.util")

function setLanAPMode()
    local OKWifiUtil = require("officekit.util.OKWifiUtil")
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local apmode = OKFunction.getNetMode() ~= nil
    local olanip = OKLanWanUtil.getLanIp()
    if not apmode then
        local uci = require("luci.model.uci").cursor()
        local lan = uci:get_all("network", "lan")
        uci:section("backup", "backup", "lan", lan)
        uci:commit("backup")
    end
    os.execute("/usr/sbin/dhcp_apclient.sh start eth0.2")
    local nlanip = OKLanWanUtil.getLanIp()
    if olanip ~= nlanip then
        local OKSync = require("officekit.util.OKSynchrodata")
        OKWifiUtil.setWiFiMacfilterModel(false)
        OKFunction.setNetMode("lanapmode")
        OKSync.syncApLanIp(nlanip)
        OKFunction.forkExec("sleep 4; /usr/sbin/ap_mode.sh open; /etc/init.d/trafficd restart; /etc/init.d/OKbc restart")
        return nlanip
    end
    return nil
end

function disableLanAP()
    local uci = require("luci.model.uci").cursor()
    local lanip = uci:get("backup", "lan", "ipaddr")
    OKFunction.setNetMode(nil)
    OKFunction.forkExec("sleep 4; /usr/sbin/ap_mode.sh close; /etc/init.d/trafficd restart; /etc/init.d/OKbc restart")
    return lanip
end

----------------------------------------------------------------
----------------------------------------------------------------

function connectionStatus()
    local connection = LuciUtil.exec("iwpriv apcli0 Connstatus")
    if connection:match("SSID:") then
        return true, connection
    else
        return false, connection
    end
end

function backupConfigs()
    local uci = require("luci.model.uci").cursor()
    local wifi = require("officekit.util.OKWifiUtil")

    local lan = uci:get_all("network", "lan")
    local dhcplan = uci:get_all("dhcp", "lan")
    local dhcpwan = uci:get_all("dhcp", "wan")

    uci:delete("backup", "lan")
    uci:delete("backup", "wifi1")
    uci:delete("backup", "wifi2")
    uci:delete("backup", "dhcplan")
    uci:delete("backup", "dhcpwan")

    uci:section("backup", "backup", "lan", lan)
    uci:section("backup", "backup", "dhcplan", dhcplan)
    uci:section("backup", "backup", "dhcpwan", dhcpwan)
    uci:commit("backup")

    wifi.backupWifiInfo(1)
    wifi.backupWifiInfo(2)
end

function setWanAuto(auto)
    local LuciNetwork = require("luci.model.network").init()
    local wan = LuciNetwork:get_network("wan")
    wan:set("auto", auto)
    LuciNetwork:commit("network")
end

function disableWifiAPMode()
    local wifi = require("officekit.util.OKWifiUtil")
    local uci = require("luci.model.uci").cursor()

    local lan = uci:get_all("backup", "lan")
    local inf = uci:get_all("backup", "wifi1")
    local inf2 = uci:get_all("backup", "wifi2")
    local dhcplan = uci:get_all("backup", "dhcplan")
    local dhcpwan = uci:get_all("backup", "dhcpwan")

    local lanip, ssid
    uci:delete("network", "lan")
    if lan then
        uci:section("network", "interface", "lan", lan)
        lanip = lan.ipaddr
    else
        uci:section("network", "interface", "lan", NETWORK_LAN)
        lanip = NETWORK_LAN.ipaddr
    end
    if dhcplan then
        uci:section("dhcp", "dhcp", "lan", dhcplan)
    end
    if dhcpwan then
        uci:section("dhcp", "dhcp", "wan", dhcpwan)
    end
    uci:commit("dhcp")
    uci:commit("network")

    setWanAuto(nil)

    wifi.deleteWifiBridgedClient(1)
    if inf then
        ssid = inf.ssid
        wifi.setWifiBasicInfo(1, inf.ssid, inf.password, inf.encryption, tostring(inf.channel), inf.txpwr, tostring(inf.hidden), tonumber(inf.on) == 1 and 0 or 1, inf.bandwidth)
    end
    if inf2 then
        wifi.setWifiBasicInfo(2, inf2.ssid, inf2.password, inf2.encryption, tostring(inf2.channel), inf2.txpwr, tostring(inf2.hidden), tonumber(inf2.on) == 1 and 0 or 1, inf2.bandwidth)
    end
    OKFunction.setNetMode(nil)
    local restore_script = [[
        sleep 3;
        /etc/init.d/network restart;
        /etc/init.d/dnsmasq restart;
        /usr/sbin/dhcp_apclient.sh restart lan;
        /etc/init.d/trafficd restart;
        /usr/sbin/shareUpdate -b
    ]]
    local sysutil = require("officekit.util.OKSysUtil")
    sysutil.setRouterName(ssid)
    OKFunction.forkExec(restore_script)
    return lanip, ssid
end

function serviceRestart()
    local restart_script = [[
        sleep 10;
        /etc/init.d/network restart;
        /etc/init.d/trafficd restart;
        /usr/sbin/shareUpdate -b;
        /etc/init.d/dnsmasq restart;
        /usr/sbin/dhcp_apclient.sh restart lan;
        /etc/init.d/OKbc restart;
        /etc/init.d/miqos stop
    ]]
    OKFunction.forkExec(restart_script)
end

function parseCmdline(str)
    if OKFunction.isStrNil(str) then
        return ""
    else
        return str:gsub("\\", "\\\\"):gsub("`", "\\`"):gsub("\"", "\\\""):gsub("%$", "\\$")
    end
end

function setWifiAPMode(ssid, encryption, enctype, password, channel, bandwidth, nssid, nencryption, npassword)
    local OKWifiUtil = require("officekit.util.OKWifiUtil")
    local result = {
        ["connected"]   = false,
        ["conerrmsg"]   = "",
        ["scan"]        = true,
        ["ip"]          = ""
    }
    local apmode = OKFunction.getNetMode() ~= nil
    local cssid = ssid
    local cenctype = enctype
    local cencryption = encryption
    local cpassword = password
    local cchannel = channel
    local cbandwidth = bandwidth
    if cssid and (cpassword or cencryption == "NONE") then
        local cmdssid = parseCmdline(cssid)
        local cmdpassword = parseCmdline(cpassword)
        if OKFunction.isStrNil(cenctype) then
            local scanlist = OKWifiUtil.getWifiScanlist(cmdssid)
            local wifi
            for _, item in ipairs(scanlist) do
                if item and item.ssid == ssid then
                    wifi = item
                    break
                end
            end
            if not wifi then
                result["scan"] = false
                return result
            end
            cchannel = wifi.channel
            cenctype = wifi.enctype
            cencryption = wifi.encryption
        end
        if apmode then
            os.execute("iwpriv apcli0 set ApCliAutoConnect=0")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("ifconfig apcli0 down")
            os.execute("sleep 1")
            os.execute("ifconfig apcli0 up")
        end
        if cenctype:match("AES") then
            -- WPA2PSK/WPA1PSK
            os.execute("iwpriv ra0 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode="..cencryption)
            os.execute("iwpriv apcli0 set ApCliEncrypType=AES")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliWPAPSK=\""..cmdpassword.."\"")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        elseif cenctype == "TKIP" then
            -- WPA2PSK/WPA1PSK
            os.execute("iwpriv ra0 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode="..cencryption)
            os.execute("iwpriv apcli0 set ApCliEncrypType=TKIP")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliWPAPSK=\""..cmdpassword.."\"")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        elseif cenctype == "WEP" then
            -- WEP
            os.execute("iwpriv ra0 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode=OPEN")
            os.execute("iwpriv apcli0 set ApCliEncrypType=WEP")
            os.execute("iwpriv apcli0 set ApCliDefaultKeyID=1")
            os.execute("iwpriv apcli0 set ApCliKey1=\""..cmdpassword.."\"")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        elseif cenctype == "NONE" then
            -- NONE
            os.execute("iwpriv ra0 set Channel="..tostring(cchannel))
            os.execute("ifconfig apcli0 up")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("iwpriv apcli0 set ApCliAuthMode=OPEN")
            os.execute("iwpriv apcli0 set ApCliEncrypType=NONE")
            os.execute("iwpriv apcli0 set ApCliSsid=\""..cmdssid.."\"")
            os.execute("iwpriv apcli0 set ApCliAutoConnect=1")
        end

        local connected = false
        for i=1, 10 do
            local succ, status = connectionStatus()
            if succ then
                connected = true
                break
            end
            os.execute("sleep 2")
            local reason = status:match("Disconnect reason = (.-)\n$")
            if reason then
                result["conerrmsg"] = reason:gsub("\n","")
            end
        end
        result["connected"] = connected
    end
    if result.connected then
        local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
        if not apmode then
            backupConfigs()
        end
        local uci = require("luci.model.uci").cursor()
        local oldlan = uci:get_all("network", "lan")
        setWanAuto(0)

        -- get ip
        local dhcpcode = tonumber(os.execute("sleep 2;dhcp_apclient.sh start"))
        if dhcpcode ~= 0 then
            dhcpcode = tonumber(os.execute("sleep 2;dhcp_apclient.sh start br-lan"))
        end
        local newip = OKLanWanUtil.getLanIp()
        if dhcpcode and dhcpcode == 0 then
            local OKSync = require("officekit.util.OKSynchrodata")
            local OKSysUtil = require("officekit.util.OKSysUtil")
            -- OKSysUtil.setRouterName(cssid)
            OKFunction.setNetMode("wifiapmode")
            OKSync.syncApLanIp(newip)
            result["ip"] = newip
            local uci = require("luci.model.uci").cursor()
            uci:delete("dhcp", "lan")
            uci:delete("dhcp", "wan")
            uci:commit("dhcp")
            local confenc
            if cenctype == "TKIPAES" then
                confenc = "mixed-psk"
            elseif cenctype == "AES" then
                confenc = "wpa2-psk"
            elseif cenctype == "TKIP" then
                confenc = "wpa-psk"
            elseif cenctype == "WEP" then
                confenc = "wep"
            elseif cenctype == "NONE" then
                confenc = "none"
            end
            local wifissid, wifipawd, wifienc = cssid, cpassword, confenc
            if nssid and nencryption and (npassword or nencryption == "none") then
                wifissid = nssid
                wifipawd = npassword
                wifienc = nencryption
            end
            local wifi5gssid = wifissid.."_5G"
            if string.len(wifi5gssid) > 31 then
                wifi5gssid = wifissid
            end
            OKWifiUtil.setWifiBasicInfo(1, wifissid, wifipawd, wifienc, cchannel, nil, "0", 1, cbandwidth)
            OKWifiUtil.setWifiBasicInfo(2, wifi5gssid, wifipawd, wifienc, nil, nil, "0", 1, nil)
            OKWifiUtil.setWifiBridgedClient(1, cssid, cencryption, cenctype, cpassword, cchannel)
            OKWifiUtil.setWiFiMacfilterModel(false)
            result["ssid"] = wifissid
        else
            setWanAuto(nil)
            if apmode then
                OKFunction.forkRestartWifi(true)
            else
                local uci = require("luci.model.uci").cursor()
                uci:delete("network", "lan")
                uci:section("network", "interface", "lan", oldlan)
                uci:commit("network")
                os.execute("iwpriv apcli0 set ApCliAutoConnect=0")
                os.execute("iwpriv apcli0 set ApCliEnable=0")
                os.execute("ifconfig apcli0 down")
            end
        end
    else
        if apmode then
            OKFunction.forkRestartWifi()
        else
            os.execute("iwpriv apcli0 set ApCliAutoConnect=0")
            os.execute("iwpriv apcli0 set ApCliEnable=0")
            os.execute("ifconfig apcli0 down")
        end
    end
    return result
end
