local redis = require "resty.redis"
local util = require "resty.acme.util"
local fmt   = string.format
local log   = util.log
local ngx_ERR = ngx.ERR
local unpack = unpack

local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  conf = conf or {}
  local self =
    setmetatable(
    {
      host = conf.host or '127.0.0.1',
      port = conf.port or 6379,
      database = conf.database,
      auth = conf.auth,
      ssl = conf.ssl or false,
      ssl_verify = conf.ssl_verify or false,
      ssl_server_name = conf.ssl_server_name,
      namespace = conf.namespace or "",
      scan_count = conf.scan_count or 10,
    },
    mt
  )
  return self, nil
end

local function op(self, op, ...)
  local ok, err
  local client = redis:new()
  client:set_timeouts(1000, 1000, 1000) -- 1 sec

  local sock_opts = {
    ssl = self.ssl,
    ssl_verify = self.ssl_verify,
    server_name = self.ssl_server_name,
  }
  ok, err = client:connect(self.host, self.port, sock_opts)
  if not ok then
    return nil, err
  end
  
  if self.auth then
    local _, err = client:auth(self.auth)
    if err then
      return nil, "authentication failed " .. err
    end
  end

  if self.database then
    ok, err = client:select(self.database)
    if not ok then
      return nil, "can't select database " .. err
    end
  end

  ok, err = client[op](client, ...)
  client:close()
  return ok, err
end

local function remove_namespace(namespace, keys)
  if namespace == "" then
    return keys
  else
    -- <namespace><real_key>
    local len = #namespace
    local start = len + 1
    for k, v in ipairs(keys) do
      if v:sub(1, len) == namespace then
        keys[k] = v:sub(start)
      else
        local msg = fmt("found a key '%s', expected to be prefixed with namespace '%s'",
                        v, namespace)
        log(ngx_ERR, msg)
      end
    end

    return keys
  end
end

-- TODO: use EX/NX flag if we can determine redis version (>=2.6.12)
function _M:add(k, v, ttl)
  k = self.namespace .. k
  local ok, err = op(self, 'setnx', k, v)
  if err then
    return err
  elseif ok == 0 then
    return "exists"
  end
  if ttl then
    local _, err = op(self, 'pexpire', k, math.floor(ttl * 1000))
    if err then
      return err
    end
  end
end

function _M:set(k, v, ttl)
  k = self.namespace .. k
  local _, err = op(self, 'set', k, v)
  if err then
    return err
  end
  if ttl then
    local _, err = op(self, 'pexpire', k, math.floor(ttl * 1000))
    if err then
      return err
    end
  end
end

function _M:delete(k)
  k = self.namespace .. k
  local _, err = op(self, 'del', k)
  if err then
    return err
  end
end

function _M:get(k)
  k = self.namespace .. k
  local res, err = op(self, 'get', k)
  if res == ngx.null then
    return nil, err
  end
  return res, err
end

local empty_table = {}
function _M:list(prefix)
  prefix = prefix or ""
  prefix = self.namespace .. prefix

  local cursor = "0"
  local data = {}
  local res, err

  repeat
    res, err = op(self, 'scan', cursor, 'match', prefix .. "*", 'count', self.scan_count)

    if not res or res == ngx.null then
      return empty_table, err
    end

    local keys
    cursor, keys = unpack(res)

    for i=1,#keys do
      data[#data+1] = keys[i]
    end

  until cursor == "0"

  return remove_namespace(self.namespace, data), err
end

return _M
