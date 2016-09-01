module ("officekit.util.OKSecureUtil", package.seeall)

require("luci.util")
require("luci.sys")
local bit = require("bit")
local nixio = require "nixio", require "nixio.util"
local fs = require "nixio.fs"

local OKLog = require("officekit.OKLog")
local XSSFilter = require("xssFilter").new()
local OKFunction = require("officekit.common.OKFunction")
local OKPreference = require("officekit.OKPreference")
local OKCryptoUtil = require("officekit.util.OKCryptoUtil")

local PWDKEY = "a2ffa5c9be07488bbb04a3a47d3c5f6a"
local DECCIPERTEXT = "echo -e '%s' | openssl aes-128-cbc -d -K %s -iv '64175472480004614961023454661220' -base64"
local NONCEPATH = "/tmp/luci-nonce"

function checkid(id)
    return not not (id and #id == 40 and id:match("^[a-fA-F0-9]+$"))
end

function prepare()
    fs.mkdir(NONCEPATH, 700)
    if not sane() then
        error("Security Exception: Nonce path is not sane!")
    end
end

function sane(file)
    return luci.sys.process.info("uid")
            == fs.stat(file or NONCEPATH, "uid")
        and fs.stat(file or NONCEPATH, "modestr")
            == (file and "rw-------" or "rwx------")
end

function readNonce(id)
    if not id or not checkid(id) then
        return nil
    end
    if not sane(NONCEPATH .. "/" .. id) then
        return nil
    end
    local blob = fs.readfile(NONCEPATH .. "/" .. id)
    local func = loadstring(blob)
    setfenv(func, {})

    local nonceinfo = func()
    if type(nonceinfo) ~= "table" then
        return nil
    end
    return nonceinfo
end

function writeNonce(id, data)
    if not sane() then
        prepare()
    end
    if not checkid(id) or type(data) ~= "table" then
        return
    end
    data = luci.util.get_bytecode(data)
    local f = nixio.open(NONCEPATH .. "/" .. id, "w", 600)
    f:writeall(data)
    f:close()
end

function xssCheck(value)
    if OKFunction.isStrNil(value) then
        return value
    end
    if type(value) == "string" then
        local cvalue,message = XSSFilter:filter(value)
        if cvalue then
            return value
        else
            local OKLog = require("officekit.OKLog")
            OKLog.log(4,"XSS Warning:"..value)
            return nil
        end
    else
        return value
    end
end

function generateRedirectKey(type)
    local LuciSys = require("luci.sys")
    local LuciSauth = require("luci.sauth")
    local info = {}
    local id = LuciSys.uniqueid(16)
    info["type"] = tostring(type)
    LuciSauth.write(id,info)
    return id
end

function checkRedirectKey(key)
    if OKFunction.isStrNil(key) then
        return false
    end
    local LuciSys = require("luci.sys")
    local LuciSauth = require("luci.sauth")
    local info = LuciSauth.read(key)
    if info and type(info) == "table" then
        LuciSauth.kill(key)
        local uptime = LuciSys.uptime()
        if uptime - info.atime > 10 then
            return false
        else
            return tostring(info.type)
        end
    end
    return false
end

function ciphertextFormat(ciphertext)
    if OKFunction.isStrNil(ciphertext) then
        return ""
    end
    local len = math.ceil(#ciphertext/64)
    local str = {}
    for i=1, len do
        if i ~= len then
            table.insert(str, string.sub(ciphertext,1+(i-1)*64,64*i))
        else
            table.insert(str, string.sub(ciphertext,1+(i-1)*64,-1))
        end
    end
    return table.concat(str, "\\n")
end

function decCiphertext(user, ciphertext)
    if OKFunction.isStrNil(ciphertext) then
        return nil
    end
    local password = OKPreference.get(user, "", "account")
    local cmd = string.format(DECCIPERTEXT, ciphertextFormat(ciphertext), password)
    if os.execute(cmd) == 0 then
        return luci.util.trim(luci.util.exec(cmd))
    end
end

function savePlaintextPwd(user, plaintext)
    if OKFunction.isStrNil(user) or OKFunction.isStrNil(plaintext) then
        return false
    end
    local pwd = OKCryptoUtil.sha1(plaintext..PWDKEY)
    OKPreference.set(user, pwd, "account")
    OKFunction.nvramSet("nv_sys_pwd", pwd)
    OKFunction.nvramCommit()
    return true
end

function saveCiphertextPwd(user, ciphertext)
    if OKFunction.isStrNil(user) or OKFunction.isStrNil(ciphertext) then
        return false
    end
    local pwd = decCiphertext(user, ciphertext)
    if pwd then
        OKPreference.set(user, pwd, "account")
        OKFunction.nvramSet("nv_sys_pwd", pwd)
        OKFunction.nvramCommit()
        return true
    end
    return false
end

-- only for old pwd
function checkPlaintextPwd(user, plaintext)
    if OKFunction.isStrNil(user) or OKFunction.isStrNil(plaintext) then
        return false
    end
    local password = OKPreference.get(user, "", "account")
    local cpwd = OKCryptoUtil.sha1(plaintext..PWDKEY)
    if password == cpwd then
        return true
    else
        return false
    end
end

function checkUser(user, nonce, encStr)
    local password = OKPreference.get(user, nil, "account")
    if password and not OKFunction.isStrNil(encStr) and not OKFunction.isStrNil(nonce) then
        if OKCryptoUtil.sha1(nonce..password) == encStr then
            return true
        end
    end
    OKLog.log(4, (luci.http.getenv("REMOTE_ADDR") or "").." Authentication failed")
    return false
end

--[[
    nonce = type.."+"..deviceId.."+"..time.."+"..random
    type [0 web] [1 Android] [2 iOS] [3 Mac] [4 PC]
]]--
function checkNonce(nonce, mac)
    local LuciUtil = require("luci.util")
    local LuciSys = require("luci.sys")
    local OKCryptoUtil = require("officekit.util.OKCryptoUtil")
    if nonce and mac then
        mac = OKFunction.macFormat(mac)
        local nonceInfo = LuciUtil.split(nonce, "_")
        if #nonceInfo ~= 4 then
            OKLog.log(6,"Nonce check failed!: Illegal" .. nonce .. " remote MAC address:" .. mac)
            return false
        end
        local dtype = tonumber(nonceInfo[1])
        local deviceId = tostring(nonceInfo[2])
        local time = tonumber(nonceInfo[3])
        if dtype and deviceId then
            local key = OKCryptoUtil.sha1(dtype..deviceId)
            if dtype > 4 then
                OKLog.log(6,"Nonce check failed! Type error:" .. nonce .. " remote MAC address:" .. mac)
                return false
            end
            local cache = readNonce(key)
            if cache and type(cache) == "table" then
                if time > tonumber(cache.mark) then
                    if mac ~= cache.mac then
                        OKLog.log(6,"Mac address changed: " .. cache.mac .. " --> " .. mac, cache, nonce)
                    end
                    cache["mark"] = tostring(time)
                    writeNonce(key,cache)
                    return true
                else
                    OKLog.log(6,"Nonce check failed!: Not match" .. nonce .. " remote MAC address:" .. mac, cache)
                end
            else
                cache = {}
                cache["mark"] = tostring(time)
                cache["mac"] = mac
                writeNonce(key,cache)
                return true
            end
        end
    end
    return false
end

local SID = "officekit-web"

function passportLoginUrl()
    local LuciProtocol = require("luci.http.protocol")
    local OKConfigs = require("officekit.common.OKConfigs")
    local OKCryptoUtil = require("officekit.util.OKCryptoUtil")
    local url
    local followup = "http://miwifi.com/cgi-bin/luci/web/xmaccount"
    local tobeSign = "followup="..followup
    local sign = OKCryptoUtil.binaryBase64Enc(OKCryptoUtil.sha1Binary(tobeSign))
    if OKConfigs.SERVER_CONFIG == 0 then
        url = OKConfigs.PASSPORT_CONFIG_ONLINE_URL..
            "?callback="..LuciProtocol.urlencode(OKConfigs.OK_SERVER_ONLINE_STS_URL.."?sign="..sign.."&followup="..followup)..
            "&sid="..SID
    elseif OKConfigs.SERVER_CONFIG == 1 then
        url = OKConfigs.PASSPORT_CONFIG_PREVIEW_URL..
            "?callback="..LuciProtocol.urlencode(OKConfigs.OK_SERVER_STAGING_STS_URL.."?sign="..sign.."&followup="..followup)..
            "&sid="..SID
    end
    return url
end

function passportLogoutUrl()
    local OKSysUtil = require("officekit.util.OKSysUtil")
    local LuciProtocol = require("luci.http.protocol")
    local OKConfigs = require("officekit.common.OKConfigs")
    local url
    local uuid = OKSysUtil.getPassportBindInfo()
    if OKFunction.isStrNil(uuid) then
        return ""
    end
    local callback = "http://miwifi.com/cgi-bin/luci/web/home"
    if OKConfigs.SERVER_CONFIG == 0 then
        url = OKConfigs.PASSPORT_LOGOUT_ONLINE_URL..
            "?callback="..LuciProtocol.urlencode(callback)..
            "&sid="..SID.."&userId="..uuid
    elseif OKConfigs.SERVER_CONFIG == 1 then
        url = OKConfigs.PASSPORT_LOGOUT_PREVIEW_URL..
            "?callback="..LuciProtocol.urlencode(callback)..
            "&sid="..SID.."&userId="..uuid
    end
    return url
end

-- check wifi password
function _charMode(char)
    if char >= 48 and char <= 57 then  -- 数字
        return 1
    elseif char >= 65 and char <= 90 then  -- 大写
        return 2
    elseif char >= 97 and char <= 122 then  -- 小写
        return 4
    else  -- 特殊字符
        return 8
    end
end

function _bitTotal(num)
    local modes = 0
    for i=1,4 do
        if bit.band(num, 1) == 1 then
            modes = modes + 1
        end
        num = bit.rshift(num, 1)
    end
    return modes
end

function checkStrong(pwd)
    if OKFunction.isStrNil(pwd) or (pwd and string.len(pwd) < 8) then
        return 0
    end
    local modes = 0
    for i=1,string.len(pwd) do
        local sss = _charMode(string.byte(pwd,i))
        modes = bit.bor(modes, sss)
    end
    return _bitTotal(modes)
end

-- check url
KEY_WORDS = {
    "'",
    ";",
    "nvram",
    "dropbear",
    "bdata"
}

function _keyWordsFilter(value)
    if OKFunction.isStrNil(value) then
        return true
    else
        value = string.lower(value)
    end
    for _, keyword in ipairs(KEY_WORDS) do
        if value:match(keyword) then
            local OKLog = require("officekit.OKLog")
            OKLog.log(6,"Keyword Warning:"..value)
            return false
        end
    end
    return true
end

function cmdSafeCheck(url)
    return _keyWordsFilter(url)
end