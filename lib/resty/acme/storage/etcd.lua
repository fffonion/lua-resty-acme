local etcd = require "resty.etcd"

local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  conf = conf or {}
  local self = setmetatable({}, mt)

  local options = {
    http_host = conf.http_host or "http://127.0.0.1:4001",
    protocol = conf.protocol or "v2",
    key_prefix = conf.key_prefix or "",
    timeout = conf.timeout or 60,
    ssl_verify = conf.ssl_verify,
  }

  local client, err = etcd.new(options)
  if err then
    return nil, err
  end

  self.client = client
  self.protocol_is_v2 = options.protocol == "v2"
  return self, nil
end

-- set the key regardless of it's existence
function _M:set(k, v, ttl)
  local _, err = self.client:set(k, v, ttl)
  if err then
    return err
  end
end

-- set the key only if the key doesn't exist
function _M:add(k, v, ttl)
  local res, err = self.client:setnx(k, v, ttl)
  if err then
    return err
  end
  if res and res.body and res.body.errorCode == 105 then
    return "exists"
  end
end

function _M:delete(k)
  local _, err = self.client:delete(k)
  if err then
    return err
  end
end

function _M:get(k)
  local res, err = self.client:get(k)
  if err then
    return nil, err
  elseif res.status == 404 and res.body and res.body.errorCode == 100 then
    return nil, nil
  elseif res.status ~= 200 then
    return nil, "etcd returned status " .. res.status
  end
  local node = res.body.node
  -- is it already expired but not evited ?
  if node.expiration and not node.ttl and self.protocol_is_v2 then
    return nil, nil
  end
  return node.value
end

local empty_table = {}
function _M:list(prefix)
  local res, err = self.client:get("/")
  if err then
    return nil, err
  elseif not res or not res.body or not res.body.node or not res.body.node.nodes then
    return empty_table, nil
  end
  local ret = {}
  -- offset 1 to strip leading "/" in original key
  local prefix_length = #prefix + 1
  for _, node in ipairs(res.body.node.nodes) do
    local key = node.key
    if key then
      -- start from 2 to strip leading "/"
      if key:sub(2, prefix_length) == prefix then
        table.insert(ret, key:sub(2))
      end
    end
  end
  return ret
end

return _M
