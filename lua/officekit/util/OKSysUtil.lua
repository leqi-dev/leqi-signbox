module ("officekit.util.OKSysUtil", package.seeall)

local OKFunction = require("officekit.common.OKFunction")
local OKConfigs = require("officekit.common.OKConfigs")

function getPrivacy()
    local privacy = require("officekit.OKPreference").get("PRIVACY")
    if tonumber(privacy) and tonumber(privacy) == 1 then
        return true
    else
        return false
    end
end

function setPrivacy(agree)
    local privacy = agree and "1" or "0"
    require("officekit.OKPreference").set("PRIVACY", privacy)
end

function getSysModel()
    return OKFunction.nvramGet("model", nil)
end

function getSysType()
    local bootType = OKFunction.nvramGet("flag_boot_type", "0")
    return tonumber(bootType)
end

function usbMode()
    local LuciUtil = require("luci.util")
    local usbpath = LuciUtil.exec("cat /tmp/usbDeployRootPath.conf 2>/dev/null")
    if OKFunction.isStrNil(usbpath) then
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
    local hddfile = LuciFs.access(OKConfigs.DISK_CHECK_PATH)
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
    local initted = require("officekit.OKPreference").get(OKConfigs.PREF_IS_INITED)
    if initted then
        return true
    else
        return false
    end
end

function setSPwd()
    local LuciUtil = require("luci.util")
    --local genpwd = LuciUtil.exec("mkOKimage -I")
    local genpwd = "admin"
    if genpwd then
        local LuciSys = require("luci.sys")
        genpwd = LuciUtil.trim(genpwd)
        LuciSys.user.setpasswd("root", genpwd)
    end
end

function setInited()
    require("officekit.OKPreference").set(OKConfigs.PREF_IS_INITED, "YES")
    local LuciUtil = require("luci.util")
    LuciUtil.exec("/usr/sbin/sysapi webinitrdr set off")
    return true
end

function getChangeLog()
    local LuciFs  = require("luci.fs")
    local LuciUtil = require("luci.util")
    if LuciFs.access(OKConfigs.OK_CHANGELOG_FILEPATH) then
        return LuciUtil.exec("cat "..OKConfigs.OK_CHANGELOG_FILEPATH)
    end
    return ""
end

function getPassportBindInfo()
    local OKPreference = require("officekit.OKPreference")
    local initted = OKPreference.get(OKConfigs.PREF_IS_PASSPORT_BOUND)
    local bindUUID = OKPreference.get(OKConfigs.PREF_PASSPORT_BOUND_UUID, "")
    if not OKFunction.isStrNil(initted) and initted == "YES" and not OKFunction.isStrNil(bindUUID) then
        return bindUUID
    else
        return false
    end
end

function setPassportBound(bind,uuid)
    local OKPreference = require("officekit.OKPreference")
    local OKDBUtil = require("officekit.util.OKDBUtil")
    if bind then
        if not OKFunction.isStrNil(uuid) then
            OKPreference.set(OKConfigs.PREF_PASSPORT_BOUND_UUID,uuid)
        end
        OKPreference.set(OKConfigs.PREF_IS_PASSPORT_BOUND, "YES")
        OKPreference.set(OKConfigs.PREF_TIMESTAMP, "0")
    else
        if not OKFunction.isStrNil(uuid) then
            OKPreference.set(OKConfigs.PREF_PASSPORT_BOUND_UUID,"")
        end
        OKPreference.set(OKConfigs.PREF_IS_PASSPORT_BOUND, "NO")
        OKPreference.set(OKConfigs.PREF_BOUND_USERINFO, "")
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
    local OKPreference = require("officekit.OKPreference")
    local name = OKPreference.get(OKConfigs.PREF_ROUTER_NAME, "")
    if OKFunction.isStrNil(name) then
        local OKWifiUtil = require("officekit.util.OKWifiUtil")
        local wifistatus = OKWifiUtil.getWifiStatus(1)
        name = wifistatus.ssid or ""
    end
    return name
end

function setRouterName(routerName)
    if routerName then
        --local OKSync = require("officekit.util.OKSynchrodata")
        --OKSync.syncRouterName(routerName)
        require("officekit.OKPreference").set(OKConfigs.PREF_ROUTER_NAME, routerName)
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
    local OKPreference = require("officekit.OKPreference")
    return OKPreference.get("ROUTER_LOCALE") or ""
end

--
-- 家/单位/其它
--
function setRouterLocale(locale)
    local OKPreference = require("officekit.OKPreference")
    if locale then
        --local OKSync = require("officekit.util.OKSynchrodata")
        --OKSync.syncRouterLocale(locale)
        OKPreference.set("ROUTER_LOCALE", locale)
    end
end

function getRouterNamePending()
    return require("officekit.OKPreference").get(OKConfigs.PREF_ROUTER_NAME_PENDING, '0')
end

function setRouterNamePending(pending)
    return require("officekit.OKPreference").set(OKConfigs.PREF_ROUTER_NAME_PENDING, pending)
end

function getBindUUID()
    return require("officekit.OKPreference").get(OKConfigs.PREF_PASSPORT_BOUND_UUID, "")
end

function setBindUUID(uuid)
    return require("officekit.OKPreference").set(OKConfigs.PREF_PASSPORT_BOUND_UUID, uuid)
end

function setBindUserInfo(userInfo)
    local LuciJson = require("json")
    local OKPreference = require("officekit.OKPreference")
    local OKConfigs = require("officekit.common.OKConfigs")
    local OKCryptoUtil = require("officekit.util.OKCryptoUtil")
    if userInfo and type(userInfo) == "table" then
        local userInfoStr = LuciJson.encode(userInfo)
        OKPreference.set(OKConfigs.PREF_BOUND_USERINFO,OKCryptoUtil.binaryBase64Enc(userInfoStr))
    end
end

function getBindUserInfo()
    local LuciJson = require("json")
    local OKPreference = require("officekit.OKPreference")
    local OKConfigs = require("officekit.common.OKConfigs")
    local OKCryptoUtil = require("officekit.util.OKCryptoUtil")
    local infoStr = OKPreference.get(OKConfigs.PREF_BOUND_USERINFO,nil)
    if infoStr and infoStr ~= "" then
        infoStr = OKCryptoUtil.binaryBase64Dec(infoStr)
        if infoStr then
            return LuciJson.decode(infoStr)
        end
    else
        return nil
    end
end

function getRomVersion()
    local LuciUtil = require("luci.util")
    local romVersion = LuciUtil.exec(OKConfigs.OK_ROM_VERSION)
    if OKFunction.isStrNil(romVersion) then
        romVersion = ""
    end
    return LuciUtil.trim(romVersion)
end

function getChannel()
    local LuciUtil = require("luci.util")
    local channel = LuciUtil.exec(OKConfigs.OK_CHANNEL)
    if OKFunction.isStrNil(channel) then
        channel = ""
    end
    return LuciUtil.trim(channel)
end

-- From GPIO
function getHardwareVersion()
    local h = OKFunction.getGpioValue(14)
    local m = OKFunction.getGpioValue(13)
    local l = OKFunction.getGpioValue(12)
    local offset = h * 4 + m * 2 + l
    local char = string.char(65+offset)
    return "Ver."..char
end

function getHardwareGPIO()
    local LuciUtil = require("luci.util")
    local hardware = LuciUtil.exec(OKConfigs.OK_HARDWARE)
    if OKFunction.isStrNil(hardware) then
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
    local hardware = LuciUtil.exec(OKConfigs.OK_HARDWARE)
    if OKFunction.isStrNil(hardware) then
        hardware = ""
    else
        hardware = LuciUtil.trim(hardware)
    end
    return hardware
end

function getCFEVersion()
    local LuciUtil = require("luci.util")
    local cfe = LuciUtil.exec(OKConfigs.OK_CFE_VERSION)
    if OKFunction.isStrNil(cfe) then
        cfe = ""
    end
    return LuciUtil.trim(cfe)
end

function getKernelVersion()
    local LuciUtil = require("luci.util")
    local kernel = LuciUtil.exec(OKConfigs.OK_KERNEL_VERSION)
    if OKFunction.isStrNil(kernel) then
        kernel = ""
    end
    return LuciUtil.trim(kernel)
end

function getRamFsVersion()
    local LuciUtil = require("luci.util")
    local ramFs = LuciUtil.exec(OKConfigs.OK_RAMFS_VERSION)
    if OKFunction.isStrNil(ramFs) then
        ramFs = ""
    end
    return LuciUtil.trim(ramFs)
end

function getSqaFsVersion()
    local LuciUtil = require("luci.util")
    local sqaFs = LuciUtil.exec(OKConfigs.OK_SQAFS_VERSION)
    if OKFunction.isStrNil(sqaFs) then
        sqaFs = ""
    end
    return LuciUtil.trim(sqaFs)
end

function getRootFsVersion()
    local LuciUtil = require("luci.util")
    local rootFs = LuciUtil.exec(OKConfigs.OK_ROOTFS_VERSION)
    if OKFunction.isStrNil(rootFs) then
        rootFs = ""
    end
    return LuciUtil.trim(rootFs)
end

function getUbootVersion()
    local LuciUtil = require("luci.util")
    local NixioFs = require("nixio.fs")
    return LuciUtil.trim(NixioFs.readfile(OKConfigs.OK_UBOOT_VERSION_FILEPATH))
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
    local OKSecureUtil = require("officekit.util.OKSecureUtil")
    OKSecureUtil.savePlaintextPwd("root", "admin")
end

function checkSysPassword(oldPassword)
    local LuciSys = require("luci.sys")
    return LuciSys.user.checkpasswd("root", oldPassword)
end

function setSysPassword(newPassword)
    local LuciSys = require("luci.sys")
    local OKSecureUtil = require("officekit.util.OKSecureUtil")
    check = LuciSys.user.setpasswd("root", newPassword)
    OKSecureUtil.savePlaintextPwd("root", newPassword)
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
    local code = os.execute(OKConfigs.OK_CUT_IMAGE.."'"..filePath.."'")
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
    local chippkg = LuciUtil.exec(OKConfigs.GET_CPU_CHIPPKG)
    if chippkg then
        chippkg = tonumber(LuciUtil.trim(chippkg))
        if chippkg == 0 then
            sysInfo["hz"] = misc.cpufreq
        else
            sysInfo["hz"] = "800MHz"
        end
    else
        sysInfo["hz"] = OKFunction.hzFormat(tonumber(bogomips)*500000)
    end
    sysInfo["system"] = platform
    sysInfo["memTotal"] = string.format("%0.2f M",memtotal/1024)
    sysInfo["memFree"] = string.format("%0.2f M",memfree/1024)
    return sysInfo
end

function setMacFilter(mac,lan,wan,admin,pridisk)
    local LuciDatatypes = require("luci.cbi.datatypes")
    if not OKFunction.isStrNil(mac) and LuciDatatypes.macaddr(mac) then
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
            OKFunction.thrift_tunnel_to_datacenter(LuciJson.encode(payload))
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
    local disk = LuciUtil.exec(OKConfigs.DISK_SPACE)
    if disk and tonumber(LuciUtil.trim(disk)) then
        disk = tonumber(LuciUtil.trim(disk))
        return OKFunction.byteFormat(disk*1024)
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
    local memery = LuciUtil.exec(OKConfigs.AVAILABLE_MEMERY)
    if memery and tonumber(LuciUtil.trim(memery)) then
        return tonumber(LuciUtil.trim(memery))
    else
        return false
    end
end

function getAvailableDisk()
    local LuciUtil = require("luci.util")
    local disk = LuciUtil.exec(OKConfigs.AVAILABLE_DISK)
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
    local OKPreference = require("officekit.OKPreference")
    if not byte then
        return OKPreference.get(OKConfigs.PREF_ROM_UPLOAD_URL, nil)
    end
    local LuciSys = require("luci.sys")
    local tmpPath
    local filePath
    if byte == 0 then
        tmpPath = "/tmp/"..LuciSys.uniqueid(16)
        filePath = OKConfigs.CROM_CACHE_FILEPATH
    elseif checkDiskSpace(byte) then
        tmpPath = "/userdisk/"..LuciSys.uniqueid(16)
        filePath = OKConfigs.CROM_DISK_CACHE_FILEPATH
    elseif checkTmpSpace(byte) then
        tmpPath = "/tmp/"..LuciSys.uniqueid(16)
        filePath = OKConfigs.CROM_CACHE_FILEPATH
    end
    if filePath then
        OKPreference.set(OKConfigs.PREF_ROM_UPLOAD_URL, filePath)
    end
    return tmpPath, filePath
end

function updateUpgradeStatus(status)
    local status = tostring(status)
    os.execute("echo "..status.." > "..OKConfigs.UPGRADE_LOCK_FILE)
end

function _getUpgradeStatus()
    local LuciUtil = require("luci.util")
    local status = tonumber(LuciUtil.exec(OKConfigs.UPGRADE_STATUS))
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
    local check = os.execute(OKConfigs.FLASH_EXECUTION_CHECK)
    if check ~= 0 then
        return 1
    end
    if not LuciFs.access(OKConfigs.FLASH_PID_TMP) then
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
    if checkExecStatus(OKConfigs.CRONTAB_ROM_CHECK) == 1 then
        if status == 0 then
            return 1
        else
            return status
        end
    end
    local checkFlash = os.execute(OKConfigs.FLASH_EXECUTION_CHECK)
    if checkFlash ~= 0 then
        if checkExecStatus(OKConfigs.CROM_FLASH_CHECK) == 1 then
            return 12
        else
            return 5
        end
    end
    local flashStatus = getFlashStatus()
    local execute = LuciFs.access(OKConfigs.CRONTAB_PID_TMP)
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
    local OKPreference = require("officekit.OKPreference")
    local OKDownloadUtil = require("officekit.util.OKDownloadUtil")
    local checkFlash = os.execute(OKConfigs.FLASH_EXECUTION_CHECK)
    if checkFlash ~= 0 then
        return false
    end
    local pid = LuciUtil.exec(OKConfigs.UPGRADE_PID)
    local luapid = LuciUtil.exec(OKConfigs.UPGRADE_LUA_PID)
    if not OKFunction.isStrNil(pid) then
        pid = LuciUtil.trim(pid)
        os.execute("kill "..pid)
        if not OKFunction.isStrNil(luapid) then
            os.execute("kill "..LuciUtil.trim(luapid))
        end
        OKDownloadUtil.cancelDownload(OKPreference.get(OKConfigs.PREF_ROM_DOWNLOAD_URL, ""))
        OKFunction.sysUnlock()
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
    local temperature = LuciUtil.exec(OKConfigs.CPU_TEMPERATURE)
    if not OKFunction.isStrNil(temperature) then
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
    local OKSecureUtil = require("officekit.util.OKSecureUtil")
    local network = {}
    local targetUrl = (target == nil or not OKSecureUtil.cmdSafeCheck(target)) and "http://www.baidu.com" or target
    if targetUrl and targetUrl:match("http://") == nil and targetUrl:match("https://") == nil then
        targetUrl = "http://"..targetUrl
    end
    local result
    if tonumber(simple) == 1 then
        result = LuciUtil.exec(OKConfigs.SIMPLE_NETWORK_NOLOG_DETECT.."'"..targetUrl.."'")
    elseif tonumber(simple) == 2 then
        result = LuciUtil.exec(OKConfigs.SIMPLE_NETWORK_DETECT.."'"..targetUrl.."'")
    else
        result = LuciUtil.exec(OKConfigs.FULL_NETWORK_DETECT.."'"..targetUrl.."'")
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
    status["cpu"] = tonumber(LuciUtil.trim(LuciUtil.exec(OKConfigs.CPU_LOAD_AVG))) or 0
    status["mem"] = tonumber(LuciUtil.trim(LuciUtil.exec(OKConfigs.MEMERY_USAGE))) or 0
    status["link"] = string.upper(LuciUtil.trim(LuciUtil.exec(OKConfigs.WAN_LINK))) == "UP"
    status["wan"] = tonumber(LuciUtil.trim(LuciUtil.exec(OKConfigs.WAN_UP))) > 0
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
    local getMode = OKConfigs.GET_LAN_MODE
    if filter == "wan" then
        getMode = OKConfigs.GET_WAN_MODE
    elseif filter == "admin" then
        getMode = OKConfigs.GET_ADMIN_MODE
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
            setMode = OKConfigs.SET_LAN_WHITELIST
        else
            setMode = OKConfigs.SET_LAN_BLACKLIST
        end
    elseif filter == "wan" then
        if tonumber(mode) == 0 then
            setMode = OKConfigs.SET_WAN_WHITELIST
        else
            setMode = OKConfigs.SET_WAN_BLACKLIST
        end
    elseif filter == "admin" then
        if tonumber(mode) == 0 then
            setMode = OKConfigs.SET_ADMIN_WHITELIST
        else
            setMode = OKConfigs.SET_ADMIN_BLACKLIST
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
    local permission = LuciUtil.exec(OKConfigs.GET_FLASH_PERMISSION)
    if OKFunction.isStrNil(permission) then
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
        LuciUtil.exec(OKConfigs.SET_FLASH_PERMISSION.."1")
    else
        LuciUtil.exec(OKConfigs.SET_FLASH_PERMISSION.."0")
    end
end

function getNvramConfigs()
    local configs = {}
    configs["wifi_ssid"] = OKFunction.nvramGet("nv_wifi_ssid", "")
    configs["wifi_enc"] = OKFunction.nvramGet("nv_wifi_enc", "")
    configs["wifi_pwd"] = OKFunction.nvramGet("nv_wifi_pwd", "")
    configs["rom_ver"] = OKFunction.nvramGet("nv_rom_ver", "")
    configs["rom_channel"] = OKFunction.nvramGet("nv_rom_channel", "")
    configs["hardware"] = OKFunction.nvramGet("nv_hardware", "")
    configs["uboot"] = OKFunction.nvramGet("nv_uboot", "")
    configs["linux"] = OKFunction.nvramGet("nv_linux", "")
    configs["ramfs"] = OKFunction.nvramGet("nv_ramfs", "")
    configs["sqafs"] = OKFunction.nvramGet("nv_sqafs", "")
    configs["rootfs"] = OKFunction.nvramGet("nv_rootfs", "")
    configs["sys_pwd"] = OKFunction.nvramGet("nv_sys_pwd", "")
    configs["wan_type"] = OKFunction.nvramGet("nv_wan_type", "")
    configs["pppoe_name"] = OKFunction.nvramGet("nv_pppoe_name", "")
    configs["pppoe_pwd"] = OKFunction.nvramGet("nv_pppoe_pwd", "")
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
    fac["ssh"] = tonumber(OKFunction.nvramGet("ssh_en", 0)) == 1 and true or false
    fac["uart"] = tonumber(OKFunction.nvramGet("uart_en", 0)) == 1 and true or false
    fac["telnet"] = tonumber(OKFunction.nvramGet("telnet_en", 0)) == 1 and true or false
    fac["facmode"] = tonumber(LuciUtil.exec("cat /proc/officekit/ft_mode 2>/dev/null")) == 1 and true or false
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
    if not OKFunction.isStrNil(result) then
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
    if not OKFunction.isStrNil(color) then
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
    local OKWifiUtil = require("officekit.util.OKWifiUtil")
    local OKLanWanUtil = require("officekit.util.OKLanWanUtil")
    local json = require("cjson")
    local wifi = OKWifiUtil.getWifiStatus(1) or {}
    local info = {
        ["hardware"] = getHardware(),
        ["channel"] = getChannel(),
        ["color"] = getColor(),
        ["locale"] = getRouterLocale(),
        ["ssid"] = wifi.ssid or "",
        ["ip"] = OKLanWanUtil.getLanIp()
    }
    return json.encode(info)
end

-- for mini system
function partitions()
    local LuciUtil = require("luci.util")
    local par = LuciUtil.execl("cat /proc/partitions")
    local partition
    for _,line in ipairs(par) do
        if not OKFunction.isStrNil(line) then
            local space, name = line:match("%s+%S+%s+%S+%s+(%S+)%s+(%S+)")
            if tonumber(space) and name and name:match("^sd%S%d") and not name:match("^sda") then
                partition = {
                    ["name"] = "/dev/"..name,
                    ["space"] = OKFunction.byteFormat(tonumber(space) * 1024)
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
        if not OKFunction.isStrNil(line) then
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
    if not OKFunction.isStrNil(status) then
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
    if not OKFunction.isStrNil(pid) then
        os.execute("kill -9 "..pid)
    end
end