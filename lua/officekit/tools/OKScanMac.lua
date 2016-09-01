module ("officekit.tools.OKScanMac", package.seeall) 

local OKFunction = require("officekit.common.OKFunction")
local OKHttpUtil = require("officekit.util.OKHttpUtil")
local LuciJson = require("json")

function _macScan()
	local maclist_j = OKHttpUtil.httpGetRequest("http://192.168.51.1/mac.json")
	local maclist = LuciJson.decode(maclist_j.res)
	local segment = maclist["segment"]
	local fequency = maclist["fequency"]
	local mac_arr = maclist["macs"]
	local LuciUtil = require "luci.util"
	local scanlist = LuciUtil.execi("nmap -sP "..segment)
	if scanlist then
		for line in scanlist do
			local valide = valideStr(line)
			if valide then
				local mac = string.sub(line, 13, 30):match("(%S+)")
				if _inMacList(mac_arr,mac) then	
					print(mac)
				end
			end
		end
	end
end

function _inMacList(list,mac)
	for i = 1, #list do
		if mac == list[i]["mac"] then 
			return true
		end
	end

	return false
end

function valideStr(str)
	if OKFunction.isStrNil(str) then
		return false
	end
	if string.match(str,"MAC Address:") then
		return true
	end
	return false
end

_macScan()
