local redis = require "resty.redis"

local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  local self =
    setmetatable(
    {
      host = conf.host or '127.0.0.1',
      port = conf.port or 6379,
      database = conf.database,
    },
    mt
  )
  return self, nil
end

local function op(self, op, ...)
  local client = ngx.ctx.acme_redis_storage
  if not client then
    client = redis:new()
    local ok, err = client:connect(
      self.host,
      self.port
    )
    if not ok then
      return nil, err
    end
    ngx.ctx.acme_redis_storage = client
  end

  if conf.database then
    local ok, err = client:select(database)
    if not ok then
      return nil, "can't select database " .. err
    end
  end

  ok, err = client[op](client, ...)
  client:set_keepalive(10000, 100)
  return ok, err
end

function _M:set(k, v)
  local ok, err = op(self, 'set', k, v)
  if err then
    return err
  end
end

function _M:delete(k)
  local ok, err = op(self, 'delete', k)
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

function _M:keys(prefix)
  local res, err = op(self, 'keys', prefix)
  if res == ngx.null then
    return nil, err
  end
  return res, err
end

return _M
