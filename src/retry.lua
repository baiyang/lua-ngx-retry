-- 定义一个类
local policy = {}

-- 类的构造函数
function policy:new(policy_name, func, max_tries, retry_delay)
    local obj = {
        name = policy_name,
        max_tries = max_tries,
        retry_delay = retry_delay,
        tries = 0,
        func = func
    }
    self.__index = self
    return setmetatable(obj, self)
end

local Retry = {}

function Retry:new()
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    -- 重试策略字典
    obj['policy'] = {}
    return obj
end

--
function Retry:apply_policy(policy_name, check_if_retry, max_tries, retry_delay)
    local policy_obj = policy:new(policy_name, check_if_retry, max_tries, retry_delay)
    table.insert(self.policy, policy_obj)
end

function Retry:run(func, ...)
    local res = { func(...) }


    -- 遍历数组并调用对象的方法
    while true do
        local success = true
        for i, obj in ipairs(self.policy) do
            -- 如果判断需要重试
            if obj.func(unpack(res)) then
                success = false
                ngx.sleep(obj.retry_delay)

                res = { func(...) }
                obj.tries = obj.tries + 1
                ngx.log(ngx.ERR, "Retrying based on ", obj.name, " policy. Retries: ", obj.tries, ". Maximum retries: ",
                    obj.max_tries)
            end
        end
        if success then
            break
        end
        local should_exited = false
        for i, obj in ipairs(self.policy) do
            if obj.tries >= obj.max_tries then
                should_exited = true
                break
            end
        end
        if should_exited then
            break
        end
    end

    return unpack(res)
end

return Retry
