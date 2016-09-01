module ("officekit.OKCountryCode", package.seeall)

local OKFunction = require("officekit.common.OKFunction")



function _(text)
    local i18n = require "luci.i18n"
    return i18n.translate(text)
end

COUNTRY_CODE = {
    {["c"] = "CN", ["n"] = _("中国大陆"), ["p"] = true},
    {["c"] = "HK", ["n"] = _("香港地区"), ["p"] = true},
    {["c"] = "TW", ["n"] = _("台湾地区"), ["p"] = true},
    {["c"] = "US", ["n"] = _("美国"), ["p"] = false},
    {["c"] = "SG", ["n"] = _("新加坡"), ["p"] = false},
    {["c"] = "MY", ["n"] = _("马来西亚"), ["p"] = false},
    {["c"] = "IN", ["n"] = _("印度"), ["p"] = false},
    {["c"] = "CA", ["n"] = _("加拿大"), ["p"] = false},
    {["c"] = "FR", ["n"] = _("法国"), ["p"] = false},
    {["c"] = "DE", ["n"] = _("德国"), ["p"] = false},
    {["c"] = "IT", ["n"] = _("意大利"), ["p"] = false},
    {["c"] = "ES", ["n"] = _("西班牙"), ["p"] = false},
    {["c"] = "PH", ["n"] = _("菲律宾"), ["p"] = false},
    {["c"] = "ID", ["n"] = _("印度尼西亚"), ["p"] = false},
    {["c"] = "TH", ["n"] = _("泰国"), ["p"] = false},
    {["c"] = "VN", ["n"] = _("越南"), ["p"] = false},
    {["c"] = "BR", ["n"] = _("巴西"), ["p"] = false},
    {["c"] = "RU", ["n"] = _("俄罗斯"), ["p"] = false},
    {["c"] = "MX", ["n"] = _("墨西哥"), ["p"] = false},
    {["c"] = "TR", ["n"] = _("土耳其"), ["p"] = false}
}

REGION = {
    ["CN"] = {["region"] = 1, ["regionABand"] = 0},
    ["TW"] = {["region"] = 0, ["regionABand"] = 19},
    ["HK"] = {["region"] = 1, ["regionABand"] = 0},
    ["US"] = {["region"] = 0, ["regionABand"] = 0}
}

LANGUAGE = {
    ["CN"] = "zh_cn",
    ["TW"] = "zh_tw",
    ["HK"] = "zh_hk",
    ["US"] = "en"
}

JLANGUAGE = {
    ["zh_cn"] = "zh_CN",
    ["zh_tw"] = "zh_TW",
    ["zh_hk"] = "zh_HK",
    ["en"]    = "en_US"
}

function getCountryCodeList()
    local clist = {}
    for _, item in ipairs(COUNTRY_CODE) do
        if item and item.p then
            table.insert(clist, {
                ["name"] = item.n,
                ["code"] = item.c
            })
        end
    end
    return clist
end

function getCurrentCountryCode()
    local OKSysUtil = require("officekit.util.OKSysUtil")
    local ccode = OKFunction.nvramGet("CountryCode")
    local channel = OKSysUtil.getChannel()
    if OKFunction.isStrNil(ccode) or channel ~= "release" then
        return "CN"
    end
    return ccode
end

function setCurrentCountryCode(ccode)
    if OKFunction.isStrNil(ccode) or REGION[ccode] == nil or LANGUAGE[ccode] == nil then
        return false
    end
    local OKSysUtil = require("officekit.util.OKSysUtil")
    local OKWifiUtil = require("officekit.util.OKWifiUtil")
    OKFunction.nvramSet("CountryCode", ccode)
    OKFunction.nvramCommit()
    -- OKSysUtil.setLang(LANGUAGE[ccode])
    OKWifiUtil.setWifiRegion(ccode, REGION[ccode].region, REGION[ccode].regionABand)
    return true
end

function getCurrentJLan()
    local OKSysUtil = require("officekit.util.OKSysUtil")
    local channel = OKSysUtil.getChannel()
    local llan = OKSysUtil.getLang() or "zh_cn"
    if channel ~= "release" then
        llan = "zh_cn"
    end
    return JLANGUAGE[llan]
end
