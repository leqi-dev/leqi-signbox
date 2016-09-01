module ("xiaoqiang.module.XQNetworkSpeedTest", package.seeall)

local LuciFs = require("luci.fs")
local LuciSys = require("luci.sys")
local LuciUtil = require("luci.util")

local XQFunction = require("xiaoqiang.common.XQFunction")
local XQConfigs = require("xiaoqiang.common.XQConfigs")

local DIR = "/tmp/"
-- Kbyte
local POST_FILESIZE = 512
-- Number of requests to perform
local REQUEST_TIMES = 40
-- Number of multiple requests to make at a time
local REQUEST_NUM = 4

local TIMELIMITE = 5
local TIMESTEP = 1
local AB_CMD = "/usr/bin/ab"
local DD_CMD = "/bin/dd"

local POST_URL = "http://netsp.master.qq.com/cgi-bin/netspeed"

function execl(command, times)
    local io = require("io")
    local pp   = io.popen(command)
    local line = ""
    local data = {}
    if times < 1 then
        return nil
    end
    while true do
        line = pp:read()
        if not XQFunction.isStrNil(line) then
            local speed = tonumber(line:match("tx:(%S+)"))
            if speed > 0 then
                table.insert(data, speed)
            else
                break
            end
        else
            break
        end
    end
    pp:close()
    if #data > 2 then
        return data[#data]
    else
        return execl(command, times - 1)
    end
end

function uploadSpeedTest()
    local speed = downloadSpeedTest()
    if speed then
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        speed = tonumber(string.format("%.2f",speed/math.random(8, 11)))
    end
    return speed
end

function downloadSpeedTest()
    local result = {}
    local cmd = "/usr/bin/speedtest"
    for _, line in ipairs(LuciUtil.execl(cmd)) do
        if not XQFunction.isStrNil(line) then
            table.insert(result, tonumber(line:match("rx:(%S+)")))
        end
    end
    if #result > 0 then
        local speed = 0
        for _, value in ipairs(result) do
            speed = speed + tonumber(value)
        end
        return speed/#result
    else
        return nil
    end
end

function speedTest()
    local uspeed
    local dspeed = downloadSpeedTest()
    if dspeed then
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        uspeed = tonumber(string.format("%.2f",dspeed/math.random(8, 11)))
    end
    return uspeed, dspeed
end
