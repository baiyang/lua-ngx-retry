
local config = {
    -- 是否开启当后端服务503重试
    ENABLE_RETRY_ON_503 = true,
    -- 503错误时默认重试间隔为3秒
    RETRY_DELAY_ON_503 = 3,     
    -- 503错误时，默认最大重试次数为10
    MAX_RETRIES_ON_503 = 20,

    -- 是否开启当后端服务502重试
    ENABLE_RETRY_ON_502 = true,
    -- 502错误时默认重试间隔为3秒
    RETRY_DELAY_ON_502 = 3, 
    -- 502错误时，默认最大重试次数为10
    MAX_RETRIES_ON_502 = 10,
    -- 单位是s. 代理请求超时时长
    PROXY_READ_TIMEOUT = 60,
    --  服务注册到该地址下，供lua插件调用，充分利用好nginx自带的upstream功能
    LUA_INTERNAL_SERVER_URL = "http://127.0.0.1:5080",
     
}

return config