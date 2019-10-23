local redis = require "resty.redis"

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
    },
    mt
  )
  return self, nil
end

local function op(self, op, ...)
  local ok, err
  local client = redis:new()
  client:set_timeouts(1000, 1000, 1000) -- 1 sec

  ok, err = client:connect(
    self.host,
    self.port
  )
  if not ok then
    return nil, err
  end
  
  if self.auth then
    ok, err = client:auth(self.auth)
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

function _M:set(k, v)
  local ok, err = op(self, 'set', k, v)
  if err then
    return err
  end
end

function _M:delete(k)
  local ok, err = op(self, 'del', k)
  if err then
    return err
  end
end

function _M:get(k)
  local res, err = op(self, 'get', k)
  if res == ngx.null then
    return nil, err
  end
  return res, err
end

local empty_table = {}
function _M:list(prefix)
  prefix = prefix or ""
  local res, err = op(self, 'keys', prefix .. "*")
  if not res or res == ngx.null then
    return empty_table, err
  end
  return res, err
end

return _M
