local http = require("resty.http")
local cjson = require("cjson")
local util = require("resty.acme.util")
local openssl = require("resty.acme.openssl")

local encode_base64url = util.encode_base64url
local decode_base64url = util.decode_base64url

local log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO
local ngx_DEBUG = ngx.DEBUG
local ngx_WARN = ngx.DEBUG

local json = cjson.new()
-- some implemntations like ZeroSSL doesn't like / to be escaped
if json.encode_escape_forward_slash then
  json.encode_escape_forward_slash(false)
end

local wait_backoff_series = {1, 1, 2, 3, 5, 8, 13, 21}

local _M = {
  _VERSION = '0.7.1'
}
local mt = {__index = _M}

local default_config = {
  -- the ACME v2 API endpoint to use
  api_uri = "https://acme-v02.api.letsencrypt.org/directory",
  -- the account email to register
  account_email = nil,
  -- the account key in PEM format text
  account_key = nil,
  -- the account kid (as an URL)
  account_kid = nil,
  -- external account binding key id
  eab_kid = nil,
  -- external account binding hmac key, base64url encoded
  eab_hmac_key = nil,
  -- external account registering handler
  eab_handler = nil,
  -- storage for challenge
  storage_adapter = "shm",
  -- the storage config passed to storage adapter
  storage_config = {
    shm_name = "acme"
  },
  -- the challenge types enabled
  enabled_challenge_handlers = {"http-01"},
  -- select preferred root CA issuer's Common Name if appliable
  preferred_chain = nil,
  -- callback function that allows to wait before signaling ACME server to validate
  challenge_start_callback = nil,
}

local function new_httpc()
  local httpc = ngx.ctx.acme_httpc
  if not httpc then
    httpc = http.new()
    ngx.ctx.acme_httpc = httpc
  end
  return httpc
end

local function set_account_key(self, account_key)
  local account_pkey = openssl.pkey.new(account_key)
  self.account_pkey = account_pkey
  local account_thumbprint, err = util.thumbprint(account_pkey)
  if err then
    return false, "failed to calculate thumbprint: " .. err
  end
  self.account_thumbprint = account_thumbprint
  return true, nil
end

function _M.new(conf)
  conf = setmetatable(conf or {}, {__index = default_config})

  local self = setmetatable(
    {
      directory = nil,
      conf = conf,
      account_pkey = nil,
      account_kid = conf.account_kid,
      nonce = nil,
      eab_required = false, -- CA requires external account binding or not
      eab_handler = conf.eab_handler,
      eab_kid = conf.eab_kid,
      eab_hmac_key = decode_base64url(conf.eab_hmac_key),
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

  if conf.account_key then
    local _, err = set_account_key(self, conf.account_key)
    if err then
      return nil, err
    end
  end

  return self
end

_M.set_account_key = set_account_key

function _M:init()
  local httpc = new_httpc()

  local resp, err = httpc:request_uri(self.conf.api_uri)
  if err then
    return "acme directory request failed: " .. err
  end

  if resp and resp.status == 200 and resp.headers["content-type"] and
      resp.headers["content-type"]:match("application/json")
   then
    local directory = json.decode(resp.body)
    if not directory then
      return "acme directory listing response malformed"
    end
    self.directory = directory
  else
    local status = resp and resp.status
    local content_type = resp and resp.headers and resp.headers["content-type"]
    return string.format("acme directory listing failed: status code %s, content-type %s",
            status, content_type)
  end

  if not self.directory["newNonce"] or
      not self.directory["newAccount"] or
      not self.directory["newOrder"] or
      not self.directory["revokeCert"] then
    return "acme directory endpoint is missing at least one of "..
            "newNonce, newAccount, newOrder or revokeCert endpoint"
  end

  if self.directory['meta'] and
      self.directory['meta']['externalAccountRequired'] then

    self.eab_required = true

    if not self.eab_handler and
      (not self.eab_kid or not self.eab_hmac_key) then

      -- try to load a predefined eab handler
      local website = self.directory['meta'] and self.directory['meta']['website']
      if website then
        -- load the module based on website metadata
        website = ngx.re.sub(website, [=[^https?://([^/]+).*$]=], "$1"):gsub("%.", "-")
        local pok, eab_handler_module = pcall(require, "resty.acme.eab." .. website)
        if pok and eab_handler_module and eab_handler_module.handle then
          log(ngx_INFO, "loaded EAB module ", "resty.acme.eab." .. website)
          self.eab_handler = eab_handler_module.handle
          return
        end
      end

      return "CA requires external account binding, either define a eab_handler to automatically "..
            "register account, or define eab_kid and eab_hmac_key for existing account"
    end
  end

  return nil
end

--- Enclose the provided payload in JWS
--
-- @param url       ACME service URL
-- @param payload   (json) data which will be wrapped in JWS
-- @param nonce     nonce to be used in JWS, if not provided new nonce will be requested
function _M:jws(url, payload, nonce)
  if not self.account_pkey then
    return nil, "account key does not specified"
  end

  if not url then
    return nil, "url is not defined"
  end

  if not nonce then
    local err
    nonce, err = self:new_nonce()
    if err then
      return nil, "can't get new nonce from acme server: " .. err
    end
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

    if self.eab_required then
      local eab_jws = {
        protected = {
          alg = "HS256",
          kid = self.eab_kid,
          url = url
        },
        payload = jws.protected.jwk,
      }

      log(ngx_DEBUG, "eab jws payload: ", json.encode(eab_jws))

      eab_jws.protected = encode_base64url(json.encode(eab_jws.protected))
      eab_jws.payload = encode_base64url(json.encode(eab_jws.payload))
      local hmac = openssl.hmac.new(self.eab_hmac_key, "SHA256")
      local sig = hmac:final(eab_jws.protected .. "." .. eab_jws.payload)
      eab_jws.signature = encode_base64url(sig)

      payload['externalAccountBinding'] = eab_jws
    end
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
function _M:post(url, payload, headers, nonce)
  local httpc = new_httpc()
  if not headers then
    headers = {
      ["content-type"] = "application/jose+json"
    }
  elseif not headers["content-type"] then
    headers["content-type"] = "application/jose+json"
  end

  local jws, err = self:jws(url, payload, nonce)
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
  if resp.headers['Content-Type']:sub(1, 16) == "application/json" then
    body = json.decode(resp.body)
  elseif resp.headers['Content-Type']:sub(1, 24) == "application/problem+json" then
    body = json.decode(resp.body)
    if body.type == 'urn:ietf:params:acme:error:badNonce' and resp.headers["Replay-Nonce"] then
      if not nonce then
        log(ngx_WARN, "bad nonce: recoverable error, retrying")
        return self:post(url, payload, headers, resp.headers["Replay-Nonce"])
      else
        return nil, nil, "bad nonce: failed again, bailing out"
      end
    else
      return nil, nil, body.detail or body.type
    end
  else
    body = resp.body
  end

  return body, resp.headers, err
end

function _M:new_account()
  if self.account_kid then
    return self.account_kid, nil
  end

  local payload = {
    termsOfServiceAgreed = true,
  }

  if self.conf.account_email then
    payload['contact'] = {
      "mailto:" .. self.conf.account_email,
    }
  end

  if self.eab_required then
    if not self.eab_handler then
      return nil, "eab_handler undefined while EAB is required by CA"
    end
    local eab_kid, eab_hmac_key, err = self.eab_handler(self.conf.account_email)
    if err then
      return nil, "eab_handler returned an error: " .. err
    end
    self.eab_kid = eab_kid
    self.eab_hmac_key = decode_base64url(eab_hmac_key)
  end

  local _, headers, err = self:post(self.directory["newAccount"], payload)

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

local function watch_order_status(self, order_url, target)
  local order_status, err
  for _, t in pairs(wait_backoff_series) do
    ngx.sleep(t)
    -- POST-as-GET request with empty payload
    order_status, _, err = self:post(order_url)
    log(ngx_DEBUG, "check order: ", json.encode(order_status), " err: ", err)
    if order_status then
      if order_status.status == target then
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

  if order_status.status ~= target then
    return nil, "failed to wait for order status, got " .. (order_status.status or "nil")
  end

  return order_status
end


local rel_alternate_pattern = '<(.+)>;%s*rel="alternate"'
local function parse_alternate_link(headers)
  local link_header = headers["Link"]
  if type(link_header) == "string" then
    return link_header:match(rel_alternate_pattern)
  elseif link_header then
    for _, link in pairs(link_header) do
      local m = link:match(rel_alternate_pattern)
      if m then
        return m
      end
    end
  end
end

function _M:finalize(finalize_url, order_url, csr)
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

  -- Wait until the order is valid: ready to download
  if not resp.certificate and resp.status and resp.status == "valid" then
    log(ngx_DEBUG, json.encode(resp))
    return nil, "no certificate object returned " .. (resp.detail or "")
  end

  local order_status, err = watch_order_status(self, order_url, "valid")
  if not order_status or not order_status.certificate then
    return nil, "error checking finalize: " .. err
  end

  -- POST-as-GET request with empty payload
  local body, headers, err = self:post(order_status.certificate)
  if err then
    return nil, "failed to fetch certificate: " .. err
  end

  local preferred_chain = self.conf.preferred_chain
  if not preferred_chain then
    return body
  end

  local ok, err = util.check_chain_root_issuer(body, preferred_chain)
  if not ok then
    log(ngx_DEBUG, "configured preferred chain issuer CN \"", preferred_chain, "\" not found ",
                    "in default chain, downloading alternate chain: ", err)
    local alternate_link = parse_alternate_link(headers)
    if not alternate_link then
      log(ngx_WARN, "failed to fetch alternate chain because no alternate link is found, ",
                    "fallback to default chain")
    else
      local body_alternate, _, err = self:post(alternate_link)

      if err then
        log(ngx_WARN, "failed to fetch alternate chain, fallback to default: ", err)
      else
        local ok, err = util.check_chain_root_issuer(body_alternate, preferred_chain)
        if ok then
          log(ngx_DEBUG, "alternate chain is selected")
          return body_alternate
        end
        log(ngx_WARN, "configured preferred chain issuer CN \"", preferred_chain, "\" also not found ",
                      "in alternate chain, fallback to default chain: ", err)
      end
    end
  end

  return body
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
  local order_url = order_headers["location"]
  local authzs = order_body.authorizations
  local registered_challenges = {}
  local registered_challenge_count = 0
  local has_valid_challenge = false

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
      if challenge.status ~= 'pending' then
        if challenge.status == 'valid' then
          has_valid_challenge = true
        end
        log(ngx_DEBUG, "challenge ", typ, ": ", challenge.token, " is ", challenge.status, ", skipping")
      elseif self.challenge_handlers[typ] then
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
        if self.conf.challenge_start_callback then
          while not self.conf.challenge_start_callback(typ, challenge.token) do
            ngx.sleep(1)
          end
        end
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

  if registered_challenge_count == 0 and not has_valid_challenge then
    return nil, "no challenge is registered and no challenge is valid"
  end

  -- Wait until the order is ready
  local order_status, err = watch_order_status(self, order_url, "ready")
  if not order_status then
    return nil, "error checking challenge: " .. err
  end

  local domain_pkey, err = openssl.pkey.new(domain_key)
  if err then
    return nil, "failed to load domain pkey: " .. err
  end

  local csr, err = util.create_csr(domain_pkey, ...)
  if err then
    return nil, "failed to create csr: " .. err
  end

  local cert, err = self:finalize(finalize_url, order_url, csr)
  if err then
    return nil, err
  end

  log(ngx_DEBUG, "order is completed: ", order_url)

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
