local http = require "resty.http"
local cjson = require "cjson.safe"

local _M = {}
local mt = {__index = _M}
local auth

local function valid_vault_key(key)
  local newstr, _ = ngx.re.gsub(key, [=[[/]]=], "-")
  return newstr
end

function _M.new(conf)
  conf = conf or {}

  local prefix = conf.kv_path
  if not prefix then
    prefix = "/acme"
  elseif prefix:sub(1, 1) ~= "/" then
    prefix = "/" .. prefix
  end
  local mount, err = ngx.re.match(prefix, "(/[^/]+)")
  if err then
    return err
  end
  mount = mount[0]
  local path = prefix:sub(#mount+1)
  local metadata_url = "/v1" .. mount .. "/metadata" .. path .. "/"
  local data_url = "/v1" .. mount .. "/data" .. path .. "/"

  local tls_verify = conf.tls_verify
  if tls_verify == nil then
    tls_verify = true
  end

  local self =
    setmetatable(
    {
      host = conf.host or "127.0.0.1",
      port = conf.port or 8200,
      auth_method = string.lower(conf.auth_method or "token"),
      auth_path = conf.auth_path or "kubernetes",
      auth_role = conf.auth_role,
      jwt_path = conf.jwt_path or "/var/run/secrets/kubernetes.io/serviceaccount/token",
      https = conf.https,
      tls_verify = tls_verify,
      tls_server_name = conf.tls_server_name,
      timeout = conf.timeout or 2000,
      data_url = data_url,
      metadata_url = metadata_url,
    },
    mt
  )

  local token, err = auth(self, conf)

  if err then
    return nil, err
  end

  self.headers = {
    ["X-Vault-Token"] = token
  }

  if self.https then
    if not self.tls_server_name then
      self.tls_server_name = self.host
    end
    self.headers["Host"] = self.tls_server_name
  end
  return self, nil
end

local function api(self, method, uri, payload)
  local _, err
  -- vault don't keepalive, we create a new instance for every request
  local client = http:new()
  client:set_timeout(self.timeout)

  local payload = payload and cjson.encode(payload)

  _, err = client:connect(self.host, self.port)
  if err then
    return nil, err
  end
  if self.https then
    local _, err = client:ssl_handshake(nil, self.tls_server_name, self.tls_verify)
    if err then
      return nil, "unable to SSL handshake with vault server: " .. err
    end
  end
  local res, err = client:request({
    path = uri,
    method = method,
    headers = self.headers,
    body = payload,
  })
  if err then
    return nil, err
  end

  -- return "soft error" for not found and successful delete
  if res.status == 404 or res.status == 204 then
    client:close()
    return nil, nil
  end

  local body, err = res:read_body()
  if err then
    client:close()
    return nil, "unable to read response body: " .. err
  end

  -- "true" "false" is also valid through cjson
  local decoded, err = cjson.decode(body)
  if not decoded then
    client:close()
    return nil, "unable to decode response body: " .. (err or 'nil') .. "body: " .. (body or 'nil')
  end

  client:close()
  if decoded.errors then
    return nil, "errors from vault: " .. cjson.encode(decoded.errors)
  end

  return decoded, err
end

function auth(self, conf)
  if self.auth_method == "token" then
    return conf.token, nil
  elseif self.auth_method ~= "kubernetes" then
    return nil, "Unknown authentication method"
  end

  local file, err = io.open(self.jwt_path, "r")

  if err then 
    return nil, err
  end

  local token = file:read("*all")
  file:close()

  local response, err = api(self, "POST", "/v1/auth/" .. self.auth_path .. "/login", {
    role = self.auth_role,
    jwt = token
  })

  if err then 
    return nil, err
  end

  if not response["auth"] or not response["auth"]["client_token"] then
    return nil, "Could not authenticate"  
  end

  return response["auth"]["client_token"]
end

local function set_cas(self, k, v, cas, ttl)
  if ttl then
    if ttl > 0 and ttl < 1 then
      ngx.log(ngx.WARN, "vault doesn't support ttl less than 1s, will use 1s")
      ttl = 1
    end
    -- first update the metadata
    local _, err = api(self, "POST", self.metadata_url .. valid_vault_key(k), {
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
  local res, err = api(self, "POST", self.data_url .. valid_vault_key(k), payload)
  if not res or err then
    return err or "set key failed"
  end
  return nil
end

local function get(self, k)
  local res, err = api(self, 'GET', self.data_url .. valid_vault_key(k))
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
  local _, err = api(self, "DELETE", self.metadata_url .. valid_vault_key(k))
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
    local key, _ = ngx.re.match(key, [[([^/]+)$]], "jo")
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
