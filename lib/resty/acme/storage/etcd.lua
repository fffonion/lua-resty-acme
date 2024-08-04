local etcd = require "resty.etcd"

local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  conf = conf or {}
  local self = setmetatable({}, mt)

  if conf.protocol and conf.protocol ~= "v3" then
      return nil, "only v3 protocol is supported"
  end

  local options = {
    http_host = conf.http_host or "http://127.0.0.1:4001",
    key_prefix = conf.key_prefix or "",
    timeout = conf.timeout or 60,
    ssl_verify = conf.ssl_verify,
    protocol = "v3",
  }

  local client, err = etcd.new(options)
  if err then
    return nil, err
  end

  self.client = client
  return self, nil
end

local function grant(self, ttl)
  local res, err = self.client:grant(ttl)
  if err then
    return nil, err
  end
  return res.body.ID
end

-- set the key regardless of it's existence
function _M:set(k, v, ttl)
  k = "/" .. k

  local lease_id, err
  if ttl then
    lease_id, err = grant(self, ttl)
    if err then
      return err
    end
  end

  local _, err = self.client:set(k, v, { lease = lease_id })
  if err then
    return err
  end
end

-- set the key only if the key doesn't exist
-- Note: the key created by etcd:setnx can't be attached to a lease later, it seems to be a bug
function _M:add(k, v, ttl)
  k = "/" .. k

  local lease_id, err
  if ttl then
    lease_id, err = grant(self, ttl)
    if err then
      return err
    end
  end


  local compare = {
    {
      key = k,
      target = "CREATE",
      create_revision = 0,
    }
  }

  local success = {
    {
      requestPut = {
        key = k,
        value = v,
        lease = lease_id,
      }
    }
  }

  local v, err = self.client:txn(compare, success)
  if err then
    return nil, err
  elseif v and v.body and not v.body.succeeded then
    return "exists"
  end
end

function _M:delete(k)
  k = "/" .. k
  local _, err = self.client:delete(k)
  if err then
    return err
  end
end

function _M:get(k)
  k = "/" .. k
  local res, err = self.client:get(k)
  if err then
    return nil, err
  elseif res and res.body.kvs == nil then
    return nil, nil
  elseif res.status ~= 200 then
    return nil, "etcd returned status " .. res.status
  end
  local node = res.body.kvs[1]
  if not node then -- would this ever happen?
    return nil, nil
  end
  return node.value
end

local empty_table = {}
function _M:list(prefix)
  local res, err = self.client:readdir("/" .. prefix)
  if err then
    return nil, err
  elseif not res or not res.body or not res.body.kvs then
    return empty_table, nil
  end
  local ret = {}
  -- offset 1 to strip leading "/" in original key
  local prefix_length = #prefix + 1
  for _, node in ipairs(res.body.kvs) do
    local key = node.key
    if key then
      -- start from 2 to strip leading "/"
      if key:sub(2, prefix_length) == prefix then
        table.insert(ret, key:sub(2))
      end
    end
  end
  return ret, nil
end

return _M
