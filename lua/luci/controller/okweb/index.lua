module("luci.controller.okweb.index", package.seeall)

function index()
    local root = node()
    if not root.target then
        root.target = alias("okweb")
        root.index = true
    end
    local page   = node("okweb")
    page.target  = firstchild()
    page.title   = _("")
    page.order   = 10
    page.sysauth = "root"
    page.mediaurlbase = "/officekit/okweb"
    page.sysauth_authenticator = "htmlauth"
    page.index = true
	entry({"okweb"}, alias("okweb", "home"), _("..............."), 10)
	entry({"okweb", "home"}, template("okweb/sysauth"), _("..............."), 12)
	entry({"okweb", "init"}, alias("okweb", "init", "hello"), _("..............."), 13)
	entry({"okweb", "init", "hello"}, call("action_hello"), _("............"), 14,true)
	entry({"okweb", "init", "guide"}, template("okweb/init/guide"), _("............"), 14,true)

	entry({"okweb", "setting"}, alias("okweb", "setting", "upgrade"), _("路由设置"), 16)
    	entry({"okweb", "setting", "upgrade"}, template("okweb/setting/upgrade"), _("路由手动升级"), 17)
	entry({"okweb", "setting", "wan"}, template("okweb/setting/wan"), _("外网设置"), 19)
end

function action_hello()                                                           
    local OKSysUtil = require("officekit.util.OKSysUtil")                           
    if OKSysUtil.getInitInfo() then                                                 
        luci.http.redirect(luci.dispatcher.build_url())                              
    else                                                                             
        OKSysUtil.setSysPasswordDefault()                                            
    end                                                                              
    local tpl = require("luci.template")                                             
    tpl.render("okweb/init/hello")                                                                         
end
