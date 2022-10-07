#! /usr/bin/env lua

json = require("cjson")
curl = require("cURL")
socket = require("socket")

DownloadFile = "/tmp/speedtest_down_results"
UploadFile = "/tmp/speedtest_up_results"
ServersListFile = "/tmp/server_list"
IpInfoFile = "/tmp/ip_info"
ServersList = "https://raw.githubusercontent.com/DDumanTT/lua_speedtest/main/servers.json"
UserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36"

Status = {
    RUNNING  = "running",
    FINISHED = "finished",
    FAILED   = "failed"
}

t = nil

function ProgressFunctionDown(totalDown, downloaded, _, _)
    local result = { status = Status.RUNNING, down_speed = 0 }
    local down_speed_exact = downloaded / 1000000 / (socket.gettime() - t)
    local down_speed = tonumber(string.format("%.2f", down_speed_exact * 8)) -- conversion to bits

    result.down_speed = down_speed
    io.open(DownloadFile, "w"):write(json.encode(result)):close()
end

function ProgressFunctionUp(_, _, totalUp, uploaded)
    local result = { status = Status.RUNNING, up_speed = 0 }
    local up_speed_exact = uploaded / 1000000 / (socket.gettime() - t)
    local up_speed = tonumber(string.format("%.2f", up_speed_exact * 8))

    result.up_speed = up_speed
    io.open(UploadFile, "w"):write(json.encode(result)):close()
end

function DownloadTest(host)
    local handle, err = io.open(DownloadFile, "w")
    if not handle then
        error(err)
    end

    t = socket.gettime()
    local e = curl.easy({
        url = host .. "/download",
        accept_encoding = "gzip, deflate, br",
        useragent = UserAgent,
        writefunction = function() end,
        progressfunction = ProgressFunctionDown,
        noprogress = false,
        timeout = 10
    })
    local status, err = pcall(e.perform, e)
    if not status then
        error(err)
        return
    end

    local handle, err = io.open(DownloadFile, "r+")
    if not handle then
        error(err)
    end

    local result = json.decode(handle:read("a"))
    result.status = Status.FINISHED
    handle:write(json.encode(result)):close()
end

function UploadTest(host)
    local handle, err = io.open(UploadFile, "w")
    if not handle then
        error(err)
    end
    
    local zero, err = io.open("/dev/zero", "r")
    if not zero then
        error(err)
    end

    t = socket.gettime()
    local e = curl.easy({
        url = host .. "/upload",
        accept_encoding = "gzip, deflate, br",
        useragent = UserAgent,
        post = true,
        httppost = curl.form({
            file = {
                file = "/dev/zero",
                type = "text/plain",
                name = "zeros"
            }
        }),
        writefunction = function() end,
        readfunction = zero,
        progressfunction = ProgressFunctionUp,
        noprogress = false,
        timeout = 10
    })
    local status, err = pcall(e.perform, e)
    if not status then
        error(err)
        return
    end

    local handle, err = io.open(UploadFile, "r+")
    if not handle then
        error(err)
    end
    local result = json.decode(handle:read("a"))
    result.status = Status.FINISHED
    handle:write(json.encode(result)):close()
    zero:close()
end

function GetIpInfo()
    local output
    local e = curl.easy({
        url = "http://ip-api.com/json/",
        useragent = UserAgent,
        writefunction = function(str) output = str end
    })

    local status, err = pcall(e.perform, e)
    if not status then
        error(err)
    end

    io.stdout:write(output)
    return json.decode(output)
end

function GetServersList()
    local handle, err = io.open(ServersListFile, "w")
    if not handle then
        error(err)
    end

    local e = curl.easy({
        url = ServersList,
        useragent = UserAgent,
        writefunction = handle
    })
    local status, err = pcall(e.perform, e)
    if not status then
        error(err)
    end

end

function GetBestServer()
    -- GetServersList()
    local file, err = io.open(ServersListFile, "r")
    if not file then
        error(err)
    end
    local servers = json.decode(file:read("a"))
    -- local country = GetIpInfo().country

    -- print(country)

    -- for i, server in ipairs(servers) do
    --     if server.Country == country then
    --         local e = curl.easy({
    --             url = server.Host.."/hello",
    --             useragent = UserAgent,
    --             nobody = true,
    --             followlocation = true
    --         })
    --         local status, err = pcall(e.perform, e)
    --         if status then
    --             print(e.getinfo(curl.INFO_CONNECT_TIME))
    --         end
    --     end
    -- end

end

function main()
    local argparse = require("argparse")

    local parser = argparse()
    parser:mutex(
        parser:option("-d --download"):argname("<host>"),
        parser:option("-u --upload"):argname("<host>"),
        parser:flag("-i --ip"),
        parser:flag("-s --servers_list"),
        parser:flag("-b --best_server")
    )
    local args = parser:parse()

    -- print(json.encode(args))

    if args.download then
        DownloadTest(args.download)
    elseif args.upload then
        UploadTest(args.upload)
    elseif args.ip then
        GetIpInfo()
    elseif args.servers_list then
        GetServersList()
    elseif args.best_server then
        GetBestServer()
    end
end

main()
