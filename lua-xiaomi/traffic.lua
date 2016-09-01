-- called by trafficd from c
-- yubo@xiaomi.com
-- 2014-09-05

local dev
local equ
local dbDict
local dhcpDict


function get_hostname_init()
	dev = require("xiaoqiang.util.XQDeviceUtil")
	equ = require("xiaoqiang.XQEquipment")
	dbDict = dev.getDeviceInfoFromDB()
	dhcpDict = dev.getDHCPDict()
end

function get_hostname(mac)
	local hostname
	if dbDict[mac] and dbDict[mac]['nickname'] ~= '' then
		hostname = dbDict[mac]['nickname']
	else
		local dhcpname = dhcpDict[mac] and dhcpDict[mac]['name'] or ''
		if dhcpname == '' then
			local t = equ.identifyDevice(mac, '')
			hostname = t.name
		else
			local t = equ.identifyDevice(mac, dhcpname)
			if t.type.p + t.type.c > 0 then
				hostname = t.name
			else
				hostname = dhcpname
			end
		end
	end
	return hostname == '' and mac or hostname
end

function get_wan_dev_name()
	local ubus = require ("ubus")
	local conn = ubus.connect()
	if not conn then
		elog("Failed to connect to ubusd")
	end
	local status = conn:call("network.interface.wan", "status",{})
	conn:close()
	return (status.l3_device and status.l3_device) or status.device
end

function get_lan_dev_name()
	local ubus = require ("ubus")
	local conn = ubus.connect()
	if not conn then
		elog("Failed to connect to ubusd")
	end
	local status = conn:call("network.interface.lan", "status",{})
	conn:close()
	return (status.l3_device and status.l3_device) or status.device
end

function get_ap_hw()
	local pp = io.popen("uci get xiaoqiang.common.NETMODE")
	local model = pp:read("*line")
	pp:close()

	if model == "wifiapmode" then
		pp = io.popen("ifconfig  apcli0 | grep HWaddr")
		local data = pp:read("*line")
		local _, _, hw = string.find(data,'HWaddr%s+([0-9A-F:]+)%s*$')
		pp:close()
		return hw
	end
	if model ==  "lanapmode" then
		pp = io.popen("ifconfig  br-lan | grep HWaddr")
		local data = pp:read("*line")
		local _, _, hw = string.find(data,'HWaddr%s+([0-9A-F:]+)%s*$')
		pp:close()
		return hw
	end
	return nil
end

function trafficd_lua_done()
	os.execute("killall -q -s 10 noflushd");
end

function get_description()
	local sys = require("xiaoqiang.util.XQSysUtil")
	return sys.getRouterInfo()
end

function get_version()
	local sys = require("xiaoqiang.util.XQSysUtil")
	return sys.getRomVersion()
end

function trafficd_lua_ecos_pair_verify(repeater_token)
    local code
    local token
    local ssid
    local ssid_pwd
    local cjson=require("json")
    os.execute("/usr/sbin/ecos_pair_verify -e" .. repeater_token)
    file = io.open("/tmp/ecos.log","r")
    if file ~= nil then
        for line in file:lines() do
            local tt = cjson.decode(line)
            code = tt['code']
            token = tt['token']
            ssid = tt['ssid']
            ssid_pwd = tt['ssid_pwd']
            os.execute("logger " .. code)
            os.execute("logger " .. token)
            os.execute("logger " .. ssid)
            os.execute("logger " .. ssid_pwd)
        end
        file:close()
    end
    return code,token,ssid,ssid_pwd
end

