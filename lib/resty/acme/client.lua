local http = require("resty.http")
local json = require("cjson")
local util = require("resty.acme.util")
local openssl = require("resty.acme.openssl")

local encode_base64url = util.encode_base64url

local log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO
local ngx_DEBUG = ngx.DEBUG
local ngx_WARN = ngx.DEBUG

local _M = {
  _VERSION = '0.5.0'
}
local mt = {__index = _M}

local default_config = {
  -- the ACME v2 API endpoint to use
  api_uri = "https://acme-v02.api.letsencrypt.org",
  -- the account email to register
  account_email = nil,
  -- the account key in PEM format text
  account_key = nil,
  -- the account kid (as an URL)
  account_kid = nil,
  -- storage for challenge and IPC (TODO)
  storage_adapter = "shm",
  -- the storage config passed to storage adapter
  storage_config = {
    shm_name = "acme"
  },
  -- the challenge types enabled
  enabled_challenge_handlers = {"http-01"}
}

local function new_httpc()
  local httpc = ngx.ctx.acme_httpc
  if not httpc then
    httpc = http.new()
    ngx.ctx.acme_httpc = httpc
  end
  return httpc
end

function _M.new(conf)
  conf = setmetatable(conf or {}, {__index = default_config})

  if not conf.account_key then
    return nil, "account_key is not defined"
  end

  local self = setmetatable(
    {
      directory = nil,
      conf = conf,
      account_pkey = openssl.pkey.new(conf.account_key),
      account_kid = conf.account_kid,
      nonce = nil,
      challenge_handlers = {}
    }, mt
  )

  local storage_adapter = conf.storage_adapter
  -- TODO: catch error and return gracefully
  if not storage_adapter:find("%.") then
    storage_adapter = "resty.acme.storage." .. storage_adapter
  end
  local storagemod = require(storage_adapter)
  local storage, err = storagemod.new(conf.storage_config)
  if err then
    return nil, err
  end
  self.storage = storage

  if not conf.enabled_challenge_handlers then
    return nil, "at least one challenge handler is needed"
  end

  -- TODO: catch error and return gracefully
  for _, c in ipairs(conf.enabled_challenge_handlers) do
    local handler = require("resty.acme.challenge." .. c)
    self.challenge_handlers[c] = handler.new(self.storage)
  end

  local account_thumbprint, err = util.thumbprint(self.account_pkey)
  if err then
    return nil, "failed to calculate thumbprint: " .. err
  end

  self.account_thumbprint = account_thumbprint

  return self
end

function _M:init()
  local httpc = new_httpc()

  local resp, err = httpc:request_uri(self.conf.api_uri .. "/directory")
  if err then
    return err
  end

  if
    resp and resp.status == 200 and resp.headers["content-type"] and
      resp.headers["content-type"]:match("application/json")
   then
    local directory = json.decode(resp.body)
    if not directory then
      return "acme directory listing response malformed"
    end
    self.directory = directory
  end


  assert(self.directory["newNonce"])
  assert(self.directory["newAccount"])
  assert(self.directory["newOrder"])
  assert(self.directory["revokeCert"])
  return nil
end

--- Enclose the provided payload in JWS
--
-- @param url        ACME service URL
-- @param payload   (json) data which will be wrapped in JWS
function _M:jws(url, payload)
  if not self.account_pkey then
    return nil, "account key does not specified"
  end

  if not url then
    return nil, "url is not defined"
  end

  local nonce, err = self:new_nonce()
  if err then
    return nil, "can't get new nonce from acme server"
  end

  local jws = {
    protected = {
      alg = "RS256",
      nonce = nonce,
      url = url
    },
    payload = payload
  }

  -- TODO: much better handling
  if payload and payload.contact then
    local params, err = self.account_pkey:get_parameters()
    if not params then
      return nil, "can't get parameters from account key: " .. (err or "nil")
    end

    jws.protected.jwk = {
      e = encode_base64url(params.e:to_binary()),
      kty = "RSA",
      n = encode_base64url(params.n:to_binary())
    }
  elseif not self.account_kid then
    return nil, "account_kid is not defined, provide via config or create account first"
  else
    jws.protected.kid = self.account_kid
  end

  log(ngx_DEBUG, "jws payload: ", json.encode(jws))

  jws.protected = encode_base64url(json.encode(jws.protected))
  -- if payload is not set, we are doing a POST-as-GET (https://tools.ietf.org/html/rfc8555#section-6.3)
  -- set it to empty string
  jws.payload = payload and encode_base64url(json.encode(payload)) or ""
  local digest = openssl.digest.new("SHA256")
  digest:update(jws.protected .. "." .. jws.payload)
  jws.signature = encode_base64url(self.account_pkey:sign(digest))

  return json.encode(jws)
end

--- ACME wrapper for http.post()
--
-- @param url       ACME service URL
-- @param payload   Request content
-- @param headers   Lua table with request headers
--
-- @return Response object or tuple (nil, msg) on errors
function _M:post(url, payload, headers)
  local httpc = new_httpc()
  if not headers then
    headers = {
      ["content-type"] = "application/jose+json"
    }
  elseif not headers["content-type"] then
    headers["content-type"] = "application/jose+json"
  end

  local jws, err = self:jws(url, payload)
  if not jws then
    return nil, nil, err
  end

  local resp, err = httpc:request_uri(url,
    {
      method = "POST",
      body = jws,
      headers = headers
    }
  )

  if err then
    return nil, nil, err
  end
  log(ngx_DEBUG, "acme request: ", url, " response: ", resp.body)

  local body
  if resp.headers['Content-Type'] == "application/json" then
    body = json.decode(resp.body)
  elseif resp.headers['Content-Type'] == "application/problem+json" then
    body = json.decode(resp.body)
    return nil, nil, body.detail or body.type
  else
    body = resp.body
  end

  return body, resp.headers, err
end

function _M:new_account()
  if self.account_kid then
    return self.account_kid, nil
  end

  local _, headers, err = self:post(self.directory["newAccount"],
    {
      termsOfServiceAgreed = true,
      contact = {"mailto:" .. self.conf.account_email}
    }
  )

  if err then
    return nil, "failed to create account: " .. err
  end

  self.account_kid = headers["location"]

  return self.account_kid, nil
end

function _M:new_nonce()
  local httpc = new_httpc()
  local resp, err = httpc:request_uri(self.directory["newNonce"],
    {
      method = "HEAD"
    }
  )

  if resp and resp.headers then
    -- TODO: Expect status code 204
    -- TODO: Expect Cache-Control: no-store
    -- TODO: Expect content size 0
    return resp.headers["replay-nonce"]
  else
    return nil, "failed to fetch new nonce: " .. err
  end
end

function _M:new_order(...)
  local domains = {...}
  if domains.n == 0 then
    return nil, nil, "at least one domains should be provided"
  end

  local identifiers = {}
  for i, domain in ipairs(domains) do
    identifiers[i] = {
      type = "dns",
      value = domain
    }
  end

  local body, headers, err = self:post(self.directory["newOrder"],
    {
      identifiers = identifiers,
    }
  )

  if err then
    return nil, nil, err
  end

  return body, headers, nil
end

function _M:finalize(finalize_url, csr)
  local payload = {
    csr = encode_base64url(csr)
  }

  local resp, headers, err = self:post(finalize_url, payload)

  if err then
    return nil, "failed to send finalize request: " .. err
  end

  if not headers["content-type"] == "application/pem-certificate-chain" then
    return nil, "wrong content type"
  end

  if not resp.certificate then
    log(ngx_DEBUG, json.encode(resp))
    return nil, "no certificate object returned " .. (resp.detail or "")
  end

  -- POST-as-GET request with empty payload
  local body, _, err = self:post(resp.certificate)
  if err then
    return nil, "failed to fetch certificate: " .. err
  end
  --, key:toPEM("private"))
  return body, err
end

-- create certificate workflow, used in new cert or renewal
function _M:order_certificate(domain_key, ...)
  -- create new-order request
  local order_body, order_headers, err = self:new_order(...)
  if err then
    return nil, "failed to create new order: " .. err
  end

  log(ngx_DEBUG, "new order: ", json.encode(order_body))

  -- setup challenges
  local finalize_url = order_body.finalize
  local authzs = order_body.authorizations
  local registered_challenges = {}
  local registered_challenge_count = 0

  for _, authz in ipairs(authzs) do
    -- POST-as-GET request with empty payload
    local challenges, _, err = self:post(authz)
    if err then
      return nil, "failed to fetch authz: " .. err
    end

    if not challenges.challenges then
      log(ngx_WARN, "fetching challenges returns an error: ", err)
      goto nextchallenge
    end
    for _, challenge in ipairs(challenges.challenges) do
      local typ = challenge.type
      if self.challenge_handlers[typ] then
        local err = self.challenge_handlers[typ]:register_challenge(
          challenge.token,
          challenge.token .. "." .. self.account_thumbprint,
          {...}
        )
        if err then
          return nil, "error registering challenge: " .. err
        end
        registered_challenges[registered_challenge_count + 1] = challenge.token
        registered_challenge_count = registered_challenge_count + 1
        log(ngx_DEBUG, "register challenge ", typ, ": ", challenge.token)
        -- signal server to start challenge check
        -- needs to be empty json body rather than empty string
        -- https://tools.ietf.org/html/rfc8555#section-7.5.1
        local _, _, err = self:post(challenge.url, {})
        if err then
          return nil, "error start challenge check: " .. err
        end
      end
    end
::nextchallenge::
  end

  if registered_challenge_count == 0 then
    return nil, "no challenge is registered"
  end
  -- Wait until the order is ready
  local order_status, _
  for _, t in pairs({1, 1, 2, 3, 5, 8, 13, 21}) do
    ngx.sleep(t)
    -- POST-as-GET request with empty payload
    order_status, _, err = self:post(order_headers["location"])
    log(ngx_DEBUG, "check challenge: ", json.encode(order_status))
    if order_status then
      if order_status.status == "ready" then
        break
      elseif order_status.status == "invalid" then
        local errors = {}
        for _, authz in ipairs(order_status.authorizations) do
          local authz_status, _, err = self:post(authz)
          if err then
            log(ngx_WARN, "error fetching authorization final status:", err)
          else
            for _, c in ipairs(authz_status.challenges) do
              log(ngx_DEBUG, "authorization status: ", json.encode(c))
              local err_msg = c['type'] .. ": " .. c['status']
              if c['error'] and c['error']['detail'] then
                err_msg = err_msg .. ": " .. c['error']['detail']
              end
              errors[#errors+1] = err_msg
            end
          end
        end
        return nil, "challenge invalid: " .. table.concat(errors, "; ")
      end
    end
  end

  if not order_status then
    return nil, "could not get order status"
  end

  if order_status.status ~= "ready" then
    return nil, "failed to wait for order status, got " .. (order_status.status or "nil")
  end

  local domain_pkey, err = openssl.pkey.new(domain_key)
  if err then
    return nil, "failed to load domain pkey: " .. err
  end

  local csr, err = util.create_csr(domain_pkey, ...)
  if err then
    return nil, "failed to create csr: " .. err
  end

  local cert, err = self:finalize(finalize_url, csr)
  if err then
    return nil, err
  end

  log(ngx_DEBUG, "order is completed: ", order_headers["location"])

  for _, token in ipairs(registered_challenges) do
    for _, ch in pairs(self.challenge_handlers) do
      ch:cleanup_challenge(token, {...})
    end
  end

  return cert, nil
end

function _M:serve_http_challenge()
  if self.challenge_handlers["http-01"] then
    self.challenge_handlers["http-01"]:serve_challenge()
  else
    log(ngx_ERR, "http-01 handler is not enabled")
    ngx.exit(500)
  end
end

function _M:serve_tls_alpn_challenge()
  if self.challenge_handlers["tls-alpn-01"] then
    self.challenge_handlers["tls-alpn-01"]:serve_challenge()
  else
    log(ngx_ERR, "tls-alpn-01 handler is not enabled")
    ngx.exit(500)
  end
end

return _M
