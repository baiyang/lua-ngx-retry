local http = require("resty.http")
local Retry = require("retry")
local config = require("config")


-- 重试请求的函数
local function request(lua_internal_server_url, httpc, request_uri, method, body, headers)
    local err
    local res

    local parsed_items
    parsed_items, err = httpc:parse_uri(lua_internal_server_url)
    if err then
        return nil, "Parse path [" .. path .. "] uri error: " .. err
    end
    local scheme, host, port = parsed_items[1], parsed_items[2], parsed_items[3]

    -- First establish a connection
    local ok, ssl_session
    ok, err, ssl_session = httpc:connect({
        scheme = scheme,
        host = host,
        port = port,
    })
    if not ok then
        return nil, err
    end

    res, err = httpc:request({
        path = request_uri,
        version = 1.1,
        method = method,
        body = body,
        headers = headers,
    })
    return res, err
end

local function filter_request_headers(headers)
    local filter_keys = {
        connection = true,
    }
    local data = {}
    -- 过滤Connection头否则keep alive失效
    for k, v in pairs(headers) do
        k = string.lower(k)
        if not filter_keys[k] then
            data[k] = v
        end
    end
    return data
end

local function filter_response_headers(headers)
    local filter_keys = {
        connection = true,
        server = true,
        ["transfer-encoding"] = true,
    }
    local data = {}
    -- 过滤Connection头否则keep alive失效
    for k, v in pairs(headers) do
        k = string.lower(k)
        if not filter_keys[k] then
            data[k] = v
        end
    end
    return data
end



local _M = {}

function _M.handle_api_with_retry(opts)
    local lua_internal_server_url = opts.lua_internal_server_url or config.LUA_INTERNAL_SERVER_URL
    local enable_retry_on_503 = opts.enable_retry_on_503 or config.ENABLE_RETRY_ON_503
    local retry_delay_on_503 = opts.retry_delay_on_503 or config.RETRY_DELAY_ON_503
    local max_retries_on_503 = opts.max_retries_on_503 or config.MAX_RETRIES_ON_503
    local enable_retry_on_502 = opts.enable_retry_on_502 or config.ENABLE_RETRY_ON_502
    local retry_delay_on_502 = opts.retry_delay_on_502 or config.RETRY_DELAY_ON_502
    local max_retries_on_502 = opts.max_retries_on_502 or config.MAX_RETRIES_ON_502
    local proxy_read_timeout = opts.proxy_read_timeout or config.PROXY_READ_TIMEOUT

    local retry = Retry:new()
    --  定义重试策略

    -- 处理503错误
    if enable_retry_on_503 then
        retry:apply_policy(
            "handle_on_503",
            function(...)
                local res, err = ...
                if res and res.status == ngx.HTTP_SERVICE_UNAVAILABLE then
                    return true
                end
                return false
            end,
            max_retries_on_503,
            retry_delay_on_503
        )
    end

    -- 处理502错误
    if enable_retry_on_502 then
        retry:apply_policy(
            "handle_on_502",
            function(...)
                local res, err = ...
                if res and res.status == ngx.HTTP_BAD_GATEWAY then
                    return true
                end
                return false
            end,
            max_retries_on_502,
            retry_delay_on_502
        )
    end

    local httpc = http.new()
    httpc:set_timeout(proxy_read_timeout * 1000) -- 设定请求超时（毫秒）

    -- 构建http请求
    local body
    local ok, err
    local request_uri = ngx.var.request_uri

    -- 过滤request headers
    local headers = filter_request_headers(ngx.req.get_headers())
    local method = ngx.req.get_method()

    -- 判断是否有body
    local content_length = headers["content-length"]
    if content_length and tonumber(content_length) > 0 then
        ngx.req.read_body()
        body = ngx.req.get_body_data()
        local file_path = ngx.req.get_body_file()

        -- 是文件传输
        if not body and file_path then
            body = io.open(file_path, "rb"):read("*a")
        end
    end

    -- 注册on abort函数
    ok, err = ngx.on_abort(function()
        ngx.log(ngx.ERR, "on_abort called.")
        ngx.exit(499)
    end)
    if not ok then
        ngx.log(ngx.ERR, "failed to register the on_abort callback: ", err)
        ngx.exit(500)
    end

    -- 请求
    local response, err = retry:run(request, lua_internal_server_url, httpc, request_uri, method, body, headers)

    -- 处理返回结果
    if not response then
        ngx.log(ngx.ERR, "Request failed: ", err)
        -- 设置HTTP状态码为500或者其他您认为适合的错误码
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        -- 返回错误详细信息给客户端，可以根据需要调整错误信息的级别和细节
        ngx.print("Internal Server Error: " .. err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    ngx.status = response.status

    local response_headers = filter_response_headers(response.headers)

    for k, v in pairs(response_headers) do
        ngx.header[k] = v
    end

    local reader = response.body_reader
    local buffer_size = 8192

    repeat
        local buffer, err = reader(buffer_size)
        if err then
            ngx.log(ngx.ERR, err)
            break
        end

        if buffer then
            ngx.print(buffer)
            ngx.flush()
        end
    until not buffer

    -- 设置keep alive
    ok, err = httpc:set_keepalive()
    if not ok then
        ngx.log(ngx.ERR, "failed to set keepalive: ", err)
        return
    end
end

return _M
