local etcd = require "resty.etcd"

local _M = {}
local mt = {__index = _M}

function _M.new(conf)
    conf = conf or {}
    local self =
    setmetatable(
        {
            http_host = conf.http_host or 'http://127.0.0.1:4001',
            protocol = conf.protocol or 'v2',
            key_prefix = conf.key_prefix or '',
            ttl = conf.ttl or -1,
            timeout = conf.timeout or 60,
        },
        mt
    )
    return self, nil
end

local function operation(self, op, ...)
    local options = {}
    options.http_host = self.http_host
    options.protocol = self.protocol
    options.ttl = self.ttl
    options.key_prefix = self.key_prefix
    options.timeout = self.timeout
    local client, err = etcd.new(options)
    if err then
        return err
    end
    local res, err = client[op](client, ...)
    return res, err
end

-- set the key regardless of it's existence
function _M:set(k, v, ttl)
    local res, err = operation(self, 'set', k, v, ttl)
    if err then
        return err
    end
end

-- set the key only if the key doesn't exist
function _M:add(k, v, ttl)
    local res, err = operation(self, 'setnx', k, v, ttl)
    return err
end

function _M:delete(k)
    local res, err = operation(self, 'delete', k)
    if err then
        return err
    end
end

function _M:get(k)
    local res, err = operation(self, 'get', k)
    if err then
        return nil, err
    elseif res.status ~= 200 then
        return nil, "etcd returned status " .. res.status
    else
        return res.body.node.value
    end
end

local empty_table = {}
function _M:list(prefix)
    prefix = prefix or ""
    local res, err = operation(self, 'get', prefix)
    if not res or res == ngx.null then
        return empty_table, err
    end
    return res, err
end

return _M
