module("luci.controller.api.OKpublic", package.seeall)                                                                                                                                         
local LuciHttp = require("luci.http")     
local OKFunction = require("officekit.common.OKFunction")
                                                                                                                                                                                               
function index()                                                                                                                                                                               
        local page   = node("api","OKpublic")                                                                                                                                                  
        page.target  = firstchild()                                                                                                                                                            
        page.title   = ("")                                                                                                                                                                    
        page.order   = 100                                                                                                                                                                     
        page.sysauth = "root"                                                                                                                                                                  
        page.sysauth_authenticator = "noauth"                                                                                                                                                
        page.index = true                                                                                                                                                                      
        entry({"api", "OKpublic"}, firstchild(), (""), 100);                                                                                                                                   
        entry({"api", "OKpublic", "get_mac"}, call("getMac"), (""), 126)                                                                                                                       
end                                                                                                                                                                                            
                                                                                                                                                                                               
function getMac()        
	local mac = luci.sys.net.ip4mac(luci.http.context.request.message.env.REMOTE_HOST) or ""                       
    	local format_mac = OKFunction.macFormat(mac)
	local result = {}
	result["code"] = 0
	result["mac"] = format_mac   
        LuciHttp.write_json(result)                                                                                                                                                            
end
