local http = require "resty.http"
local cjson = require "cjson.safe"

local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  conf = conf or {}
  local base_url = conf.https and "https://" or "http://"
  base_url = base_url .. (conf.host or "127.0.0.1")
  base_url = base_url .. ":" .. (conf.port or "8500")

  local prefix = conf.kv_path
  if not prefix then
    prefix = "/acme"
  elseif prefix:sub(1, 1) ~= "/" then
    prefix = "/" .. prefix
  end
  base_url = base_url .. "/v1/kv" .. prefix .. "/"

  local self =
    setmetatable(
    {
      timeout = conf.timeout or 2000,
      base_url = base_url,
    },
    mt
  )
  self.headers = {
    ["X-Consul-Token"] = conf.token,
  }
  return self, nil
end

local function api(self, method, uri, payload)
  local ok, err
  -- consul don't keepalive, we create a new instance for every request
  local client = http:new()
  client:set_timeout(self.timeout)

  local res, err = client:request_uri(self.base_url .. uri, {
    method = method,
    headers = self.headers,
    body = payload,
  })
  if err then
    return nil, err
  end
  client:close()

  -- return "soft error" for not found
  if res.status == 404 then
    return nil, nil
  end

  -- "true" "false" is also valid through cjson
  local decoded, err = cjson.decode(res.body)
  if not decoded then
    return nil, "unable to decode response body " .. (err or 'nil')
  end
  return decoded, err
end

local function set_cas(self, k, v, cas, ttl)
  local params = {}
  if ttl then
    table.insert(params, string.format("flags=%d", (ngx.now() + ttl) * 1000))
  end
  if cas then
    table.insert(params, string.format("cas=%d", cas))
  end
  local uri = k
  if #params > 0 then
    uri = uri .. "?" .. table.concat(params, "&")
  end
  local res, err = api(self, "PUT", uri, v)
  if not res or err then
    return err or "consul returned false"
  end
end

function _M:add(k, v, ttl)
  -- update_time is called in get()
  -- we don't delete key automatically
  local vget, err = self:get(k)
  if err then
    return "error reading key " .. err
  end
  if vget then
    return "exists"
  end
  -- do cas for prevent race condition
  return set_cas(self, k, v, 0, ttl)
end

function _M:set(k, v, ttl)
  ngx.update_time()
  return set_cas(self, k, v, nil, ttl)
end

function _M:delete(k, cas)
  local uri = k
  if cas then
    uri = uri .. string.format("?cas=%d", cas)
  end
  local res, err = api(self, "DELETE", uri)
  if not res or err then
    return err or "delete key failed"
  end
end

function _M:get(k)
  local res, err = api(self, 'GET', k)
  ngx.update_time()
  if err then
    return nil, err
  elseif not res or not res[1] or not res[1]["Value"] then
    return nil, nil
  elseif res[1]["Flags"] and res[1]["Flags"] > 0 and res[1]["Flags"] < ngx.now() * 1000 then
    err = self:delete(k, res[1]["ModifyIndex"])
    if err then
      return nil, "error cleanup expired key ".. err
    end
    return nil, nil
  end
  if res[1]["Value"] == ngx.null then
    return nil, err
  end
  return ngx.decode_base64(res[1]["Value"]), err
end

local empty_table = {}
function _M:list(prefix)
  local res, err = api(self, 'GET', '?keys')
  if err then
    return nil, err
  elseif not res then
    return empty_table, nil
  end
  local ret = {}
  local prefix_length = #prefix
  for _, key in ipairs(res) do
    local key, err = ngx.re.match(key, [[([^/]+)$]], "jo")
    if key then
      key = key[1]
      if key:sub(1, prefix_length) == prefix then
        table.insert(ret, key)
      end
    end
  end
  return ret
end

return _M
