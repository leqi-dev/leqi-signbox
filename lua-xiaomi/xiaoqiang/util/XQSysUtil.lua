module ("xiaoqiang.util.XQSysUtil", package.seeall)

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")

function getPrivacy()
    local privacy = require("xiaoqiang.XQPreference").get("PRIVACY")
    if tonumber(privacy) and tonumber(privacy) == 1 then
        return true
    else
        return false
    end
end

function setPrivacy(agree)
    local privacy = agree and "1" or "0"
    require("xiaoqiang.XQPreference").set("PRIVACY", privacy)
end

function getSysModel()
    return XQFunction.nvramGet("model", nil)
end

function getSysType()
    local bootType = XQFunction.nvramGet("flag_boot_type", "0")
    return tonumber(bootType)
end

function usbMode()
    local LuciUtil = require("luci.util")
    local usbpath = LuciUtil.exec("cat /tmp/usbDeployRootPath.conf 2>/dev/null")
    if XQFunction.isStrNil(usbpath) then
        return nil
    else
        return LuciUtil.trim(usbpath)
    end
end

function getMiscHardwareInfo()
    local uci = require("luci.model.uci").cursor()
    local result = {}
    result["bbs"] = tostring(uci:get("misc", "hardware", "bbs"))
    result["cpufreq"] = tostring(uci:get("misc", "hardware", "cpufreq"))
    result["verify"] = tostring(uci:get("misc", "hardware", "verify"))
    result["gpio"] = tonumber(uci:get("misc", "hardware", "gpio")) == 1 and 1 or 0
    result["recovery"] = tonumber(uci:get("misc", "hardware", "recovery")) == 1 and 1 or 0
    result["flashpermission"] = tonumber(uci:get("misc", "hardware", "flash_per")) == 1 and 1 or 0
    return result
end

function diskExist()
    local LuciFs = require("luci.fs")
    local hddfile = LuciFs.access(XQConfigs.DISK_CHECK_PATH)
    return not hddfile
end

function isRecoveryModel()
    local misc = getMiscHardwareInfo()
    if misc.recovery == 1 then
        return true
    else
        return false
    end
end

function getInitInfo()
    local initted = require("xiaoqiang.XQPreference").get(XQConfigs.PREF_IS_INITED)
    if initted then
        return true
    else
        return false
    end
end

function setSPwd()
    local LuciUtil = require("luci.util")
    local genpwd = LuciUtil.exec("mkxqimage -I")
    if genpwd then
        local LuciSys = require("luci.sys")
        genpwd = LuciUtil.trim(genpwd)
        LuciSys.user.setpasswd("root", genpwd)
    end
end

function setInited()
    require("xiaoqiang.XQPreference").set(XQConfigs.PREF_IS_INITED, "YES")
    local LuciUtil = require("luci.util")
    LuciUtil.exec("/usr/sbin/sysapi webinitrdr set off")
    return true
end

function getChangeLog()
    local LuciFs  = require("luci.fs")
    local LuciUtil = require("luci.util")
    if LuciFs.access(XQConfigs.XQ_CHANGELOG_FILEPATH) then
        return LuciUtil.exec("cat "..XQConfigs.XQ_CHANGELOG_FILEPATH)
    end
    return ""
end

function getPassportBindInfo()
    local XQPreference = require("xiaoqiang.XQPreference")
    local initted = XQPreference.get(XQConfigs.PREF_IS_PASSPORT_BOUND)
    local bindUUID = XQPreference.get(XQConfigs.PREF_PASSPORT_BOUND_UUID, "")
    if not XQFunction.isStrNil(initted) and initted == "YES" and not XQFunction.isStrNil(bindUUID) then
        return bindUUID
    else
        return false
    end
end

function setPassportBound(bind,uuid)
    local XQPreference = require("xiaoqiang.XQPreference")
    local XQDBUtil = require("xiaoqiang.util.XQDBUtil")
    if bind then
        if not XQFunction.isStrNil(uuid) then
            XQPreference.set(XQConfigs.PREF_PASSPORT_BOUND_UUID,uuid)
        end
        XQPreference.set(XQConfigs.PREF_IS_PASSPORT_BOUND, "YES")
        XQPreference.set(XQConfigs.PREF_TIMESTAMP, "0")
    else
        if not XQFunction.isStrNil(uuid) then
            XQPreference.set(XQConfigs.PREF_PASSPORT_BOUND_UUID,"")
        end
        XQPreference.set(XQConfigs.PREF_IS_PASSPORT_BOUND, "NO")
        XQPreference.set(XQConfigs.PREF_BOUND_USERINFO, "")
    end
    return true
end

function getSysUptime()
    local LuciUtil = require("luci.util")
    local catUptime = "cat /proc/uptime"
    local data = LuciUtil.exec(catUptime)
    if data == nil then
        return 0
    else
        local t1,t2 = data:match("^(%S+) (%S+)")
        return LuciUtil.trim(t1)
    end
end

function getConfigInfo()
    local LuciUtil = require("luci.util")
    return LuciUtil.exec("cat /etc/config/*")
end

function getRouterName()
    local XQPreference = require("xiaoqiang.XQPreference")
    local name = XQPreference.get(XQConfigs.PREF_ROUTER_NAME, "")
    if XQFunction.isStrNil(name) then
        local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
        local wifistatus = XQWifiUtil.getWifiStatus(1)
        name = wifistatus.ssid or ""
    end
    return name
end

function setRouterName(routerName)
    if routerName then
        local XQSync = require("xiaoqiang.util.XQSynchrodata")
        XQSync.syncRouterName(routerName)
        require("xiaoqiang.XQPreference").set(XQConfigs.PREF_ROUTER_NAME, routerName)
        setRouterNamePending('1')
        return true
    else
        return false
    end
end

--
-- 家/单位/其它
--
function getRouterLocale()
    local XQPreference = require("xiaoqiang.XQPreference")
    return XQPreference.get("ROUTER_LOCALE") or ""
end

--
-- 家/单位/其它
--
function setRouterLocale(locale)
    local XQPreference = require("xiaoqiang.XQPreference")
    if locale then
        local XQSync = require("xiaoqiang.util.XQSynchrodata")
        XQSync.syncRouterLocale(locale)
        XQPreference.set("ROUTER_LOCALE", locale)
    end
end

function getRouterNamePending()
    return require("xiaoqiang.XQPreference").get(XQConfigs.PREF_ROUTER_NAME_PENDING, '0')
end

function setRouterNamePending(pending)
    return require("xiaoqiang.XQPreference").set(XQConfigs.PREF_ROUTER_NAME_PENDING, pending)
end

function getBindUUID()
    return require("xiaoqiang.XQPreference").get(XQConfigs.PREF_PASSPORT_BOUND_UUID, "")
end

function setBindUUID(uuid)
    return require("xiaoqiang.XQPreference").set(XQConfigs.PREF_PASSPORT_BOUND_UUID, uuid)
end

function setBindUserInfo(userInfo)
    local LuciJson = require("json")
    local XQPreference = require("xiaoqiang.XQPreference")
    local XQConfigs = require("xiaoqiang.common.XQConfigs")
    local XQCryptoUtil = require("xiaoqiang.util.XQCryptoUtil")
    if userInfo and type(userInfo) == "table" then
        local userInfoStr = LuciJson.encode(userInfo)
        XQPreference.set(XQConfigs.PREF_BOUND_USERINFO,XQCryptoUtil.binaryBase64Enc(userInfoStr))
    end
end

function getBindUserInfo()
    local LuciJson = require("json")
    local XQPreference = require("xiaoqiang.XQPreference")
    local XQConfigs = require("xiaoqiang.common.XQConfigs")
    local XQCryptoUtil = require("xiaoqiang.util.XQCryptoUtil")
    local infoStr = XQPreference.get(XQConfigs.PREF_BOUND_USERINFO,nil)
    if infoStr and infoStr ~= "" then
        infoStr = XQCryptoUtil.binaryBase64Dec(infoStr)
        if infoStr then
            return LuciJson.decode(infoStr)
        end
    else
        return nil
    end
end

function getRomVersion()
    local LuciUtil = require("luci.util")
    local romVersion = LuciUtil.exec(XQConfigs.XQ_ROM_VERSION)
    if XQFunction.isStrNil(romVersion) then
        romVersion = ""
    end
    return LuciUtil.trim(romVersion)
end

function getChannel()
    local LuciUtil = require("luci.util")
    local channel = LuciUtil.exec(XQConfigs.XQ_CHANNEL)
    if XQFunction.isStrNil(channel) then
        channel = ""
    end
    return LuciUtil.trim(channel)
end

-- From GPIO
function getHardwareVersion()
    local h = XQFunction.getGpioValue(14)
    local m = XQFunction.getGpioValue(13)
    local l = XQFunction.getGpioValue(12)
    local offset = h * 4 + m * 2 + l
    local char = string.char(65+offset)
    return "Ver."..char
end

function getHardwareGPIO()
    local LuciUtil = require("luci.util")
    local hardware = LuciUtil.exec(XQConfigs.XQ_HARDWARE)
    if XQFunction.isStrNil(hardware) then
        hardware = ""
    else
        hardware = LuciUtil.trim(hardware)
    end
    local misc = getMiscHardwareInfo()
    if misc.gpio == 1 then
        return getHardwareVersion()
    end
    return hardware
end

function getHardware()
    local LuciUtil = require("luci.util")
    local hardware = LuciUtil.exec(XQConfigs.XQ_HARDWARE)
    if XQFunction.isStrNil(hardware) then
        hardware = ""
    else
        hardware = LuciUtil.trim(hardware)
    end
    return hardware
end

function getCFEVersion()
    local LuciUtil = require("luci.util")
    local cfe = LuciUtil.exec(XQConfigs.XQ_CFE_VERSION)
    if XQFunction.isStrNil(cfe) then
        cfe = ""
    end
    return LuciUtil.trim(cfe)
end

function getKernelVersion()
    local LuciUtil = require("luci.util")
    local kernel = LuciUtil.exec(XQConfigs.XQ_KERNEL_VERSION)
    if XQFunction.isStrNil(kernel) then
        kernel = ""
    end
    return LuciUtil.trim(kernel)
end

function getRamFsVersion()
    local LuciUtil = require("luci.util")
    local ramFs = LuciUtil.exec(XQConfigs.XQ_RAMFS_VERSION)
    if XQFunction.isStrNil(ramFs) then
        ramFs = ""
    end
    return LuciUtil.trim(ramFs)
end

function getSqaFsVersion()
    local LuciUtil = require("luci.util")
    local sqaFs = LuciUtil.exec(XQConfigs.XQ_SQAFS_VERSION)
    if XQFunction.isStrNil(sqaFs) then
        sqaFs = ""
    end
    return LuciUtil.trim(sqaFs)
end

function getRootFsVersion()
    local LuciUtil = require("luci.util")
    local rootFs = LuciUtil.exec(XQConfigs.XQ_ROOTFS_VERSION)
    if XQFunction.isStrNil(rootFs) then
        rootFs = ""
    end
    return LuciUtil.trim(rootFs)
end

function getUbootVersion()
    local LuciUtil = require("luci.util")
    local NixioFs = require("nixio.fs")
    return LuciUtil.trim(NixioFs.readfile(XQConfigs.XQ_UBOOT_VERSION_FILEPATH))
end

function getLangList()
    local LuciUtil = require("luci.util")
    local LuciConfig = require("luci.config")
    local langs = {}
    for k, v in LuciUtil.kspairs(LuciConfig.languages) do
        if type(v)=="string" and k:sub(1, 1) ~= "." then
            local lang = {}
            lang['lang'] = k
            lang['name'] = v
            table.insert(langs,lang)
        end
    end
    return langs
end

function getLang()
    local LuciConfig = require("luci.config")
    return LuciConfig.main.lang
end

function setLang(lang)
    local LuciUtil = require("luci.util")
    local LuciUci = require("luci.model.uci")
    local LuciConfig = require("luci.config")
    for k, v in LuciUtil.kspairs(LuciConfig.languages) do
        if type(v) == "string" and k:sub(1, 1) ~= "." then
            if lang == k or lang == "auto" then
                local cursor = LuciUci.cursor()
                if lang=="auto" then
                    cursor:set("luci", "main" , "lang" , "auto")
                else
                    cursor:set("luci", "main" , "lang" , k)
                end
                cursor:commit("luci")
                cursor:save("luci")
                return true
            end
        end
    end
    return false
end

function setSysPasswordDefault()
    local LuciSys = require("luci.sys")
    local XQSecureUtil = require("xiaoqiang.util.XQSecureUtil")
    XQSecureUtil.savePlaintextPwd("admin", "admin")
end

function checkSysPassword(oldPassword)
    local LuciSys = require("luci.sys")
    return LuciSys.user.checkpasswd("root", oldPassword)
end

function setSysPassword(newPassword)
    local LuciSys = require("luci.sys")
    local XQSecureUtil = require("xiaoqiang.util.XQSecureUtil")
    check = LuciSys.user.setpasswd("root", newPassword)
    XQSecureUtil.savePlaintextPwd("admin", newPassword)
    if check == 0 then
        return true
    else
        local LuciUtil = require("luci.util")
        LuciUtil.exec("rm /etc/passwd+")
    end
    return false
end

function cutImage(filePath)
    if not filePath then
        return false
    end
    local code = os.execute(XQConfigs.XQ_CUT_IMAGE.."'"..filePath.."'")
    if 0 == code or 127 == code then
        return true
    else
        return false
    end
end

function verifyImage(filePath)
    if not filePath then
        return false
    end
    local verifycmd = getMiscHardwareInfo().verify
    if 0 == os.execute(verifycmd.."'"..filePath.."'") then
        return true
    else
        return false
    end
end

function getSysInfo()
    local LuciSys = require("luci.sys")
    local LuciUtil = require("luci.util")
    local misc = getMiscHardwareInfo()
    local sysInfo = {}
    local processor = LuciUtil.execl("cat /proc/cpuinfo | grep processor")
    local platform, model, memtotal, memcached, membuffers, memfree, bogomips = LuciSys.sysinfo()
    if #processor > 0 then
        sysInfo["core"] = #processor
    else
        sysInfo["core"] = 1
    end
    local chippkg = LuciUtil.exec(XQConfigs.GET_CPU_CHIPPKG)
    if chippkg then
        chippkg = tonumber(LuciUtil.trim(chippkg))
        if chippkg == 0 then
            sysInfo["hz"] = misc.cpufreq
        else
            sysInfo["hz"] = "800MHz"
        end
    else
        sysInfo["hz"] = XQFunction.hzFormat(tonumber(bogomips)*500000)
    end
    sysInfo["system"] = platform
    sysInfo["memTotal"] = string.format("%0.2f M",memtotal/1024)
    sysInfo["memFree"] = string.format("%0.2f M",memfree/1024)
    return sysInfo
end

function setMacFilter(mac,lan,wan,admin,pridisk)
    local LuciDatatypes = require("luci.cbi.datatypes")
    if not XQFunction.isStrNil(mac) and LuciDatatypes.macaddr(mac) then
        local cmd = "/usr/sbin/sysapi macfilter set mac="..mac
        if wan then
            cmd = cmd.." wan="..(wan == "1" and "yes" or "no")
        end
        if lan then
            cmd = cmd.." lan="..(lan == "1" and "yes" or "no")
            -- user disk access permission decided by datacenter
            local payload = {
                ["api"] = 75,
                ["isAdd"] = lan == "1" and true or false,
                ["isLogin"] = false,
                ["mac"] = mac
            }
            local LuciJson = require("json")
            XQFunction.thrift_tunnel_to_datacenter(LuciJson.encode(payload))
        end
        if admin then
            cmd = cmd.." admin="..(admin == "1" and "yes" or "no")
        end
        if pridisk then
            cmd = cmd.." pridisk="..(pridisk == "1" and "yes" or "no")
        end
        if os.execute(cmd..";".."/usr/sbin/sysapi macfilter commit") == 0 then
            return true
        end
    end
    return false
end

function getDiskSpace()
    local LuciUtil = require("luci.util")
    local disk = LuciUtil.exec(XQConfigs.DISK_SPACE)
    if disk and tonumber(LuciUtil.trim(disk)) then
        disk = tonumber(LuciUtil.trim(disk))
        return XQFunction.byteFormat(disk*1024)
    else
        return "Cannot find userdisk"
    end
end

-- kbyte
function getUsbSpace(path)
    local LuciUtil = require("luci.util")
    local usb = LuciUtil.exec("df -k | grep "..tostring(path).."$ | awk '{print $4}'")
    if usb then
        return LuciUtil.trim(usb)
    else
        return nil
    end
end

function getAvailableMemery()
    local LuciUtil = require("luci.util")
    local memery = LuciUtil.exec(XQConfigs.AVAILABLE_MEMERY)
    if memery and tonumber(LuciUtil.trim(memery)) then
        return tonumber(LuciUtil.trim(memery))
    else
        return false
    end
end

function getAvailableDisk()
    local LuciUtil = require("luci.util")
    local disk = LuciUtil.exec(XQConfigs.AVAILABLE_DISK)
    if disk and tonumber(LuciUtil.trim(disk)) then
        return tonumber(LuciUtil.trim(disk))
    else
        return false
    end
end

function checkDiskSpace(byte)
    local disk = getAvailableDisk()
    if disk then
        if disk - byte/1024 > 10240 then
            return true
        end
    end
    return false
end

function checkTmpSpace(byte)
    local tmp = getAvailableMemery()
    if tmp then
        if tmp - byte/1024 > 6144 then
            return true
        end
    end
    return false
end

function filePathForUpload(byte)
    local XQPreference = require("xiaoqiang.XQPreference")
    if not byte then
        return XQPreference.get(XQConfigs.PREF_ROM_UPLOAD_URL, nil)
    end
    local LuciSys = require("luci.sys")
    local tmpPath
    local filePath
    if byte == 0 then
        tmpPath = "/tmp/"..LuciSys.uniqueid(16)
        filePath = XQConfigs.CROM_CACHE_FILEPATH
    elseif checkDiskSpace(byte) then
        tmpPath = "/userdisk/"..LuciSys.uniqueid(16)
        filePath = XQConfigs.CROM_DISK_CACHE_FILEPATH
    elseif checkTmpSpace(byte) then
        tmpPath = "/tmp/"..LuciSys.uniqueid(16)
        filePath = XQConfigs.CROM_CACHE_FILEPATH
    end
    if filePath then
        XQPreference.set(XQConfigs.PREF_ROM_UPLOAD_URL, filePath)
    end
    return tmpPath, filePath
end

function updateUpgradeStatus(status)
    local status = tostring(status)
    os.execute("echo "..status.." > "..XQConfigs.UPGRADE_LOCK_FILE)
end

function _getUpgradeStatus()
    local LuciUtil = require("luci.util")
    local status = tonumber(LuciUtil.exec(XQConfigs.UPGRADE_STATUS))
    if status then
        return status
    else
        return 0
    end
end

function checkBeenUpgraded()
    if isRecoveryModel() then
        return false
    end
    local LuciUtil = require("luci.util")
    local otaFlag = tonumber(LuciUtil.trim(LuciUtil.exec("nvram get flag_ota_reboot")))
    if otaFlag == 1 then
        return true
    else
        return false
    end
end

--[[
    0 : 没有flash
    1 : 正在执行flash
    2 : flash成功 需要重启
    3 : flash失败
]]--
function getFlashStatus()
    local LuciFs = require("luci.fs")
    if checkBeenUpgraded() then
        return 2
    end
    local check = os.execute(XQConfigs.FLASH_EXECUTION_CHECK)
    if check ~= 0 then
        return 1
    end
    if not LuciFs.access(XQConfigs.FLASH_PID_TMP) then
        return 0
    else
        return 3
    end
end

function checkExecStatus(checkCmd)
    local LuciUtil = require("luci.util")
    local check = LuciUtil.exec(checkCmd)
    if check then
        check = tonumber(LuciUtil.trim(check))
        if check > 0 then
            return 1
        end
    end
    return 0
end

--[[
    0 : 没有upgrade
    1 : 检查升级
    2 : 检查tmp 磁盘是否有空间下载
    3 : 下载升级包
    4 : 检测升级包
    5 : 刷写升级包
    6 : 没有检测到更新
    7 : 没有磁盘空间
    8 : 下载失败
    9 : 升级包校验失败
    10 : 刷写失败
    11 : 升级成功
    12 : 手动升级在刷写升级包
]]--
function checkUpgradeStatus()
    local LuciFs = require("luci.fs")
    if checkBeenUpgraded() then
        return 11
    end
    local status = _getUpgradeStatus()
    if checkExecStatus(XQConfigs.CRONTAB_ROM_CHECK) == 1 then
        if status == 0 then
            return 1
        else
            return status
        end
    end
    local checkFlash = os.execute(XQConfigs.FLASH_EXECUTION_CHECK)
    if checkFlash ~= 0 then
        if checkExecStatus(XQConfigs.CROM_FLASH_CHECK) == 1 then
            return 12
        else
            return 5
        end
    end
    local flashStatus = getFlashStatus()
    local execute = LuciFs.access(XQConfigs.CRONTAB_PID_TMP)
    if execute then
        if status == 0 then
            if flashStatus == 2 then
                return 11
            elseif flashStatus == 3 then
                return 10
            end
        end
        return status
    else
        if flashStatus == 2 then
            return 11
        elseif flashStatus == 3 then
            return 10
        end
    end
    return 0
end

function isUpgrading()
    local status = checkUpgradeStatus()
    if status == 1 or status == 2 or status == 3 or status == 4 or status == 5 or status == 12 then
        return true
    else
        return false
    end
end

function cancelUpgrade()
    local LuciUtil = require("luci.util")
    local XQPreference = require("xiaoqiang.XQPreference")
    local XQDownloadUtil = require("xiaoqiang.util.XQDownloadUtil")
    local checkFlash = os.execute(XQConfigs.FLASH_EXECUTION_CHECK)
    if checkFlash ~= 0 then
        return false
    end
    local pid = LuciUtil.exec(XQConfigs.UPGRADE_PID)
    local luapid = LuciUtil.exec(XQConfigs.UPGRADE_LUA_PID)
    if not XQFunction.isStrNil(pid) then
        pid = LuciUtil.trim(pid)
        os.execute("kill "..pid)
        if not XQFunction.isStrNil(luapid) then
            os.execute("kill "..LuciUtil.trim(luapid))
        end
        XQDownloadUtil.cancelDownload(XQPreference.get(XQConfigs.PREF_ROM_DOWNLOAD_URL, ""))
        XQFunction.sysUnlock()
        return true
    else
        return false
    end
end

--[[
    Temp < 50, 属于正常
    50 < Temp < 64, 风扇可能工作不正常
    Temp > 64, 不正常风扇或温度传感器坏了
]]--
function getCpuTemperature()
    local LuciUtil = require("luci.util")
    local temperature = LuciUtil.exec(XQConfigs.CPU_TEMPERATURE)
    if not XQFunction.isStrNil(temperature) then
        temperature = temperature:match('Temperature: (%S+)')
        if temperature then
            temperature = tonumber(LuciUtil.trim(temperature))
            return temperature
        end
    end
    return 0
end

--[[
    simple : 0/1/2 (正常模式,时间长上传log/简单模式,时间短,不上传log/简单模式,时间短,上传log)
]]--
function getNetworkDetectInfo(simple,target)
    local LuciUtil = require("luci.util")
    local LuciJson = require("json")
    local XQSecureUtil = require("xiaoqiang.util.XQSecureUtil")
    local network = {}
    local targetUrl = (target == nil or not XQSecureUtil.cmdSafeCheck(target)) and "http://www.baidu.com" or target
    if targetUrl and targetUrl:match("http://") == nil and targetUrl:match("https://") == nil then
        targetUrl = "http://"..targetUrl
    end
    local result
    if tonumber(simple) == 1 then
        result = LuciUtil.exec(XQConfigs.SIMPLE_NETWORK_NOLOG_DETECT.."'"..targetUrl.."'")
    elseif tonumber(simple) == 2 then
        result = LuciUtil.exec(XQConfigs.SIMPLE_NETWORK_DETECT.."'"..targetUrl.."'")
    else
        result = LuciUtil.exec(XQConfigs.FULL_NETWORK_DETECT.."'"..targetUrl.."'")
    end
    if result then
        result = LuciJson.decode(LuciUtil.trim(result))
        if result and type(result) == "table" then
            local checkInfo = result.CHECKINFO
            if checkInfo and type(checkInfo) == "table" then
                network["wanLink"] = checkInfo.wanlink == "up" and 1 or 0
                network["wanType"] = checkInfo.wanprotocal or ""
                network["pingLost"] = checkInfo.ping:match("(%S+)%%")
                network["gw"] = checkInfo.gw:match("(%S+)%%")
                network["dns"] = checkInfo.dns == "ok" and 1 or 0
                network["tracer"] = checkInfo.tracer == "ok" and 1 or 0
                network["memory"] = tonumber(checkInfo.memory)*100
                network["cpu"] = tonumber(checkInfo.cpu)
                network["disk"] = checkInfo.disk
                network["tcp"] = checkInfo.tcp
                network["http"] = checkInfo.http
                network["ip"] = checkInfo.ip
                return network
            end
        end
    end
    return nil
end

function checkSystemStatus()
    local LuciUtil = require("luci.util")
    local status = {}
    status["cpu"] = tonumber(LuciUtil.trim(LuciUtil.exec(XQConfigs.CPU_LOAD_AVG))) or 0
    status["mem"] = tonumber(LuciUtil.trim(LuciUtil.exec(XQConfigs.MEMERY_USAGE))) or 0
    status["link"] = string.upper(LuciUtil.trim(LuciUtil.exec(XQConfigs.WAN_LINK))) == "UP"
    status["wan"] = tonumber(LuciUtil.trim(LuciUtil.exec(XQConfigs.WAN_UP))) > 0
    status["tmp"] = getCpuTemperature()
    return status
end

--[[
    lan: samba
    wan: internet
    admin: root
    return 0/1 (whitelist/blacklist)
]]--
function getMacfilterMode(filter)
    local LuciUtil = require("luci.util")
    local getMode = XQConfigs.GET_LAN_MODE
    if filter == "wan" then
        getMode = XQConfigs.GET_WAN_MODE
    elseif filter == "admin" then
        getMode = XQConfigs.GET_ADMIN_MODE
    end
    local macMode = LuciUtil.exec(getMode)
    if macMode then
        macMode = LuciUtil.trim(macMode)
        if macMode == "whitelist" then
            return 0
        else
            return 1
        end
    end
    return false
end

--[[
    filter : lan/wan/admin
    mode : 0/1 (whitelist/blacklist)
]]--
function setMacfilterMode(filter,mode)
    local LuciUtil = require("luci.util")
    local setMode
    if filter == "lan" then
        if tonumber(mode) == 0 then
            setMode = XQConfigs.SET_LAN_WHITELIST
        else
            setMode = XQConfigs.SET_LAN_BLACKLIST
        end
    elseif filter == "wan" then
        if tonumber(mode) == 0 then
            setMode = XQConfigs.SET_WAN_WHITELIST
        else
            setMode = XQConfigs.SET_WAN_BLACKLIST
        end
    elseif filter == "admin" then
        if tonumber(mode) == 0 then
            setMode = XQConfigs.SET_ADMIN_WHITELIST
        else
            setMode = XQConfigs.SET_ADMIN_BLACKLIST
        end
    end
    if setMode and os.execute(setMode) == 0 then
        return true
    else
        return false
    end
end

function getFlashPermission()
    local LuciUtil = require("luci.util")
    local permission = LuciUtil.exec(XQConfigs.GET_FLASH_PERMISSION)
    if XQFunction.isStrNil(permission) then
        return false
    else
        permission = tonumber(LuciUtil.trim(permission))
        if permission and permission == 1 then
            return true
        end
    end
    return false
end

function setFlashPermission(permission)
    local LuciUtil = require("luci.util")
    if permission then
        LuciUtil.exec(XQConfigs.SET_FLASH_PERMISSION.."1")
    else
        LuciUtil.exec(XQConfigs.SET_FLASH_PERMISSION.."0")
    end
end

function getNvramConfigs()
    local configs = {}
    configs["wifi_ssid"] = XQFunction.nvramGet("nv_wifi_ssid", "")
    configs["wifi_enc"] = XQFunction.nvramGet("nv_wifi_enc", "")
    configs["wifi_pwd"] = XQFunction.nvramGet("nv_wifi_pwd", "")
    configs["rom_ver"] = XQFunction.nvramGet("nv_rom_ver", "")
    configs["rom_channel"] = XQFunction.nvramGet("nv_rom_channel", "")
    configs["hardware"] = XQFunction.nvramGet("nv_hardware", "")
    configs["uboot"] = XQFunction.nvramGet("nv_uboot", "")
    configs["linux"] = XQFunction.nvramGet("nv_linux", "")
    configs["ramfs"] = XQFunction.nvramGet("nv_ramfs", "")
    configs["sqafs"] = XQFunction.nvramGet("nv_sqafs", "")
    configs["rootfs"] = XQFunction.nvramGet("nv_rootfs", "")
    configs["sys_pwd"] = XQFunction.nvramGet("nv_sys_pwd", "")
    configs["wan_type"] = XQFunction.nvramGet("nv_wan_type", "")
    configs["pppoe_name"] = XQFunction.nvramGet("nv_pppoe_name", "")
    configs["pppoe_pwd"] = XQFunction.nvramGet("nv_pppoe_pwd", "")
    return configs
end

function getModulesList()
    local uci = require("luci.model.uci").cursor()
    local result = {}
    local modules = uci:get_all("module", "common")
    for key, value in pairs(modules) do
        if key and value and not key:match("%.") then
            result[key] = value
        end
    end
    if _G.next(result) == nil then
        return nil
    else
        return result
    end
end

function facInfo()
    local LuciUtil = require("luci.util")
    local fac = {}
    fac["version"] = getRomVersion()
    fac["init"] = getInitInfo()
    fac["ssh"] = tonumber(XQFunction.nvramGet("ssh_en", 0)) == 1 and true or false
    fac["uart"] = tonumber(XQFunction.nvramGet("uart_en", 0)) == 1 and true or false
    fac["telnet"] = tonumber(XQFunction.nvramGet("telnet_en", 0)) == 1 and true or false
    fac["facmode"] = tonumber(LuciUtil.exec("cat /proc/xiaoqiang/ft_mode 2>/dev/null")) == 1 and true or false
    return fac
end

function _(text)
    return text
end

NETTB = {
    ["1"] = _("wan口网线未插"),
    ["2"] = _("DHCP方式时未收到DHCP服务器的回应"),
    ["3"] = _("PPPoE上网时未收到PPPoE服务器的回应"),
    ["4"] = _("DHCP方式时，上级网络与LAN有IP冲突"),
    ["5"] = _("网关不可达，需要检查上级的连接和设置"),
    ["6"] = _("DNS服务器无法服务，可以尝试自定义DNS解决（114.114.114.114, 114.114.115.115  国外8.8.8.8  8.8.4.4)"),
    ["7"] = _("自定义的DNS无法服务，请关闭自动以DNS或者重新设置"),
    ["8"] = _("无线中继，无法中继上级"),
    ["9"] = _("有线中继，无法中继上级"),
    ["10"] = _("静态IP，连接时连接断开"),
    ["31"] = _("PPPoE服务器不允许一个账号同时登录"),
    ["32"] = _("PPPoE上网是用户名或者密码错误")
}

function nettb()
    local LuciJson = require("json")
    local LuciUtil = require("luci.util")
    local nettb = {
        ["code"] = 0,
        ["reason"] = ""
    }
    local result = LuciUtil.exec("/usr/sbin/nettb")
    if not XQFunction.isStrNil(result) then
        result = LuciUtil.trim(result)
        result = LuciJson.decode(result)
        if result.code then
            nettb.code = tonumber(result.code)
            nettb.reason = NETTB[tostring(result.code)]
        end
    end
    return nettb
end

-- 黑色    100
-- 白色    101
-- 橘色    102
-- 绿色    103
-- 蓝色    104
-- 粉色    105
function getColor()
    local LuciUtil = require("luci.util")
    local color = LuciUtil.exec("nvram get color")
    if not XQFunction.isStrNil(color) then
        color = LuciUtil.trim(color)
        color = tonumber(color)
        if not color then
            color = 100
        end
    else
        color = 100
    end
    return color
end

function getRouterInfo()
    local XQWifiUtil = require("xiaoqiang.util.XQWifiUtil")
    local XQLanWanUtil = require("xiaoqiang.util.XQLanWanUtil")
    local json = require("cjson")
    local wifi = XQWifiUtil.getWifiStatus(1) or {}
    local info = {
        ["hardware"] = getHardware(),
        ["channel"] = getChannel(),
        ["color"] = getColor(),
        ["locale"] = getRouterLocale(),
        ["ssid"] = wifi.ssid or "",
        ["ip"] = XQLanWanUtil.getLanIp()
    }
    return json.encode(info)
end

-- for mini system
function partitions()
    local LuciUtil = require("luci.util")
    local par = LuciUtil.execl("cat /proc/partitions")
    local partition
    for _,line in ipairs(par) do
        if not XQFunction.isStrNil(line) then
            local space, name = line:match("%s+%S+%s+%S+%s+(%S+)%s+(%S+)")
            if tonumber(space) and name and name:match("^sd%S%d") and not name:match("^sda") then
                partition = {
                    ["name"] = "/dev/"..name,
                    ["space"] = XQFunction.byteFormat(tonumber(space) * 1024)
                }
            end
        end
    end
    return partition
end

function mountInfo()
    local LuciUtil = require("luci.util")
    local LuciFs = require("luci.fs")
    local df = LuciUtil.execl("df -h")
    local info = {}
    for _,line in ipairs(df) do
        if not XQFunction.isStrNil(line) then
            local dev, total, used, available, mounted_on = line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+%S+%s+(%S+)")
            if mounted_on == "/tmp/userdisk" then
                info["userdisk"] = {
                    ["total"]       = total,
                    ["used"]        = used,
                    ["available"]   = available
                }
            elseif mounted_on == "/tmp/usb" then
                if LuciFs.access(dev) then
                    info["usb"] = {
                        ["total"]       = total,
                        ["used"]        = used,
                        ["available"]   = available
                    }
                else
                    os.execute("umount /tmp/usb")
                end
            end
        end
    end
    return info
end

-- 0: 正常
-- 1: 未能创建路径(这个时候可能内存有问题)
-- 2: 未能挂载硬盘(这种情况需要返厂了)
-- 3: 没有USB设备(需要插入USB设备)
-- 4: 不能挂载USB设备(需要更换USB设备，可能是文件格式不支持)
function diskPrepare()
    local info = mountInfo()
    if info.userdisk and info.usb then
        return 0
    end
    os.execute("mkdir /tmp/userdisk; mkdir /tmp/usb")
    if not info.userdisk and os.execute("mount /dev/sda4 /tmp/userdisk") ~= 0 then
        return 2
    end
    local partition = partitions()
    if not partition then
        return 3
    end
    local cmd = "mount "..partition.name.." /tmp/usb"
    if os.execute(cmd) ~= 0 then
        return 4
    end
    return 0
end

function getDirectoryInfo(dpath)
    local LuciUtil = require("luci.util")
    local result = {
        ["total"] = "",
        ["info"] = {}
    }
    local dpath = dpath or "/tmp/userdisk/data/"
    if not dpath:match("/$") then
        dpath = dpath.."/"
    end
    local info = LuciUtil.execl("du -h -d 1 "..dpath)
    local count = #info
    for index, line in ipairs(info) do
        if line then
            local size, path = line:match("(%S+)%s+(%S+)")
            if path and index ~= count then
                local item = {
                    ["name"] = path:gsub(dpath, ""),
                    ["size"] = size,
                    ["path"] = path,
                    ["type"] = "folder"
                }
                table.insert(result.info, item)
            elseif path and index == count then
                result.total = size
            end
        end
    end
    local fileinfo = LuciUtil.execl("ls -lh "..dpath)
    for _, line in ipairs(fileinfo) do
        if line then
            local mod, size = line:match("(%S+)%s+%S+%s+%S+%s+%S+%s+(%S+)%s+")
            local filename = line:match("%s(%S+)$")
            if mod and not mod:match("^d") then
                local item = {
                    ["name"] = filename,
                    ["size"] = size,
                    ["path"] = dpath..filename,
                    ["type"] = "file"
                }
                table.insert(result.info, item)
            end
        end
    end
    return result
end

function backupFiles(files, target)
    if files and type(files) == "table" then
        local target = target or "/tmp/usb/mirouter_data_backup/"
        os.execute("mkdir "..target)
        for _, item in ipairs(files) do
            if item["type"] and item["path"] then
                local cp
                if item["type"] == "folder" then
                    cp = "cp -r "..item.path.." "..target
                    os.execute("echo 1 "..item.path.." > /tmp/backup_files_status")
                elseif item["type"] == "file" then
                    cp = "cp "..item.path.." "..target
                    os.execute("echo 1 "..item.path.." > /tmp/backup_files_status")
                end
                os.execute(cp)
            end
        end
    end
    os.execute("echo 2 > /tmp/backup_files_status")
end

-- 1 拷贝中
-- 2 拷贝完成
-- 3 拷贝失败
function backupStatus()
    local LuciUtil = require("luci.util")
    local result = {
        ["status"] = 0,
        ["description"] = ""
    }
    local status = LuciUtil.exec("cat /tmp/backup_files_status 2>/dev/null")
    if not XQFunction.isStrNil(status) then
        if status:match("^2") then
            result.status = 2
        elseif status:match("^1") then
            result.status = 1
            result.description = status:gsub("1 ", "")
        elseif status:match("^3") then
            result.status = 3
        end
    end
    return result
end

function cancelBackup()
    local LuciUtil = require("luci.util")
    local pid = LuciUtil.exec("cat /tmp/backup_files_pid 2>/dev/null")
    if not XQFunction.isStrNil(pid) then
        os.execute("kill -9 "..pid)
    end
end