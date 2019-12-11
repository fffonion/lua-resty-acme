local http = require "resty.http"
local cjson = require "cjson.safe"

local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  conf = conf or {}
  local base_url = conf.https and "https://" or "http://"
  base_url = base_url .. (conf.host or "127.0.0.1")
  base_url = base_url .. ":" .. (conf.port or "8200")

  local prefix = conf.kv_path
  if not prefix then
    prefix = "/acme"
  elseif prefix:sub(1, 1) ~= "/" then
    prefix = "/" .. prefix
  end
  local metadata_url = base_url .. "/v1/secret/metadata" .. prefix .. "/"
  local data_url = base_url .. "/v1/secret/data" .. prefix .. "/"

  local self =
    setmetatable(
    {
      timeout = conf.timeout or 2000,
      data_url = data_url,
      metadata_url = metadata_url,
    },
    mt
  )
  self.headers = {
    ["X-Vault-Token"] = conf.token,
  }
  return self, nil
end

local function api(self, method, uri, payload)
  local ok, err
  -- vault don't keepalive, we create a new instance for every request
  local client = http:new()
  client:set_timeout(self.timeout)

  local payload = payload and cjson.encode(payload)

  local res, err = client:request_uri(uri, {
    method = method,
    headers = self.headers,
    body = payload,
  })
  if err then
    return nil, err
  end
  client:close()

  -- return "soft error" for not found and successful delete
  if res.status == 404 or res.status == 204 then
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
  if ttl then
    if ttl > 0 and ttl < 1 then
      ngx.log(ngx.WARN, "vault doesn't support ttl less than 1s, will use 1s")
    end
    ttl = 1
    -- first update the metadata
    local _, err = api(self, "POST", self.metadata_url .. k, {
      delete_version_after = string.format("%dms", ttl * 1000)
    })
    -- vault doesn't seem return any useful info in this api ?
    if err then
      return err
    end
  end

  local payload = {
    data = {
      value = v,
      note = "managed by lua-resty-acme",
    }
  }
  if cas then
    payload.options = {
      cas = cas,
    }
  end
  local res, err = api(self, "POST", self.data_url .. k, payload)
  if not res or err then
    return err or "set key failed"
  end
  return nil
end

local function get(self, k)
  local res, err = api(self, 'GET', self.data_url .. k)
  if err then
    return nil, err
  elseif not res or not res["data"] or not res["data"]["data"] 
        or not res["data"]["data"]["value"] then
    return nil, nil
  end
  return res['data'], nil
end

function _M:add(k, v, ttl)
  -- we don't delete key automatically
  local vget, err = get(self, k)
  if err then
    return "error reading key " .. err
  end
  local revision
  -- if there's no 'data' meaning all versions are gone, then we are good
  if vget then
    if vget['data'] then
      return "exists"
    end
    revision = vget['metadata'] and vget['metadata']['version'] or 0
  end
  ngx.update_time()
  -- do cas for prevent race condition
  return set_cas(self, k, v, revision, ttl)
end

function _M:set(k, v, ttl)
  ngx.update_time()
  return set_cas(self, k, v, nil, ttl)
end

function _M:delete(k, cas)
  -- delete metadata will delete all versions of secret as well
  local _, err = api(self, "DELETE", self.metadata_url .. k)
  if err then
    return "delete key failed"
  end
end

function _M:get(k)
  local v, err = get(self, k)
  if err then
    return nil, err
  end
  return v and v["data"]["value"], err
end

local empty_table = {}
function _M:list(prefix)
  local res, err = api(self, 'LIST', self.metadata_url)
  if err then
    return nil, err
  elseif not res or not res['data'] or not res['data']['keys'] then
    return empty_table, nil
  end
  local ret = {}
  local prefix_length = #prefix
  for _, key in ipairs(res['data']['keys']) do
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
