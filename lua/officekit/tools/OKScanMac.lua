module ("officekit.tools.OKScanMac", package.seeall) 

local OKFunction = require("officekit.common.OKFunction")
local OKHttpUtil = require("officekit.util.OKHttpUtil")
local LuciJson = require("json")

function getIP()
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
	return 
    end
    return tostring(status.ip.address)

end

function _macScan()
	local reportIp = getIP()
	local maclist_j = OKHttpUtil.httpPostRequest("http://dev.api.officekit.org/macList","{\"devicesCode\":\"635c4653b3c97e01\",\"reportIp\":\""..reportIp.."\"}");
	--if pcall(LuciJson.decode) then
		local maclist = LuciJson.decode(maclist_j.res)
	--else
		--print("get maclist error")
		--return
	--end
	if OKFunction.isStrNil(maclist["code"]) or maclist["code"] ~= "000000" then
		return 
	end

	local segment = _getSegment()
	local mac_arr = maclist["data"]
	local LuciUtil = require "luci.util"
	local scanlist = LuciUtil.execi("nmap -sP "..segment)
	if scanlist then
		for line in scanlist do
			local valide = valideStr(line)
			if valide then
				local mac = string.sub(line, 13, 30):match("(%S+)")
				_inMacList(mac_arr,mac)
			end
		end
		_fillOffline(mac_arr)
		local mac_arr_raw = {["devicesCode"] = "635c4653b3c97e01", ["macList"] = mac_arr, ["reportIp"] = getIP()}
		local macarr_json = LuciJson.encode(mac_arr_raw)
		OKHttpUtil.httpPostRequest("http://dev.api.officekit.org/macList",macarr_json)		
	end
end

function _getSegment()
    	local OKLanWanUtil = require("officekit.util.OKLanWanUtil")                     
    	local wan = OKLanWanUtil.getLanWanInfo("wan")
	local mask = tostring(wan.ipv4[1].mask)
	local ip = wan.gateWay
	local ones = string.split(mask,".")
	local onecount = 0
	for k,one in pairsByKeys(ones) do
		onecount = onecount + _onecount(one)
	end
	return ip.."/"..onecount		
end

function pairsByKeys(t)      
    local a = {}      
    for n in pairs(t) do          
        a[#a+1] = n      
    end      
    table.sort(a)      
    local i = 0      
    return function()          
    i = i + 1          
    return a[i], t[a[i]]      
    end  
end


function _onecount(str)
	local result = 0
	if tonumber(str) == 0 then
		return 0
	end
	while math.floor(str/2) > 0 do
		result = result + 1
		str = str / 2
	end
	return result+1
end

function string.split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
	return nil
    end
	
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function _fillOffline(list)
        for i = 1, #list do
                if OKFunction.isStrNil(list[i]["line"]) then
                        list[i]["line"] = 2                                 
                end                                        
        end	
end

function _inMacList(list,mac)
	mac = string.lower(mac)
	for i = 1, #list do
		if mac == string.lower(list[i]["mac"]) then
			list[i]["line"] = 1
			return
		end
	end
	return
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
