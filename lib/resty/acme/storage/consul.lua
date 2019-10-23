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
  elseif path:sub(1, 1) ~= "/" then
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

function _M:set(k, v)
  local res, err = api(self, "PUT", k, v)
  if not res or err then
    return err or "set key failed"
  end
  return nil
end

function _M:delete(k)
  local res, err = api(self, "DELETE", k)
  if not res or err then
    return err or "delete key failed"
  end
end

function _M:get(k)
  local res, err = api(self, 'GET', k)
  if err then
    return nil, err
  elseif not res or not res[1] or not res[1]["Value"] then
    return nil, nil
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
