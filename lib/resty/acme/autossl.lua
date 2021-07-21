local lrucache = require "resty.lrucache"
local acme = require "resty.acme.client"
local util = require "resty.acme.util"
local openssl = require "resty.acme.openssl"
local json = require "cjson"
local ssl = require "ngx.ssl"

local log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN
local ngx_INFO = ngx.INFO
local ngx_DEBUG = ngx.DEBUG
local null = ngx.null

local AUTOSSL = {}

local default_config = {
  -- accept term of service https://letsencrypt.org/repository/
  tos_accepted = false,
  -- if using the let's encrypt staging API
  staging = false,
  -- the path to account private key in PEM format
  account_key_path = nil,
  -- the account email to register
  account_email = nil,
  -- number of certificate cache, per type
  cache_size = 100,
  domain_key_paths = {
    -- the global domain RSA private key
    rsa = nil,
    -- the global domain ECC private key
    ecc = nil,
  },
  -- the private key algorithm to use, can be one or both of
  -- 'rsa' and 'ecc'
  domain_key_types = { 'rsa' },
  -- restrict registering new cert only with domain defined in this table
  domain_whitelist = nil,
  -- restrict registering new cert only with domain checked by this function
  domain_whitelist_callback = nil,
  -- the threshold to renew a cert before it expires, in seconds
  renew_threshold = 7 * 86400,
  -- interval to check cert renewal, in seconds
  renew_check_interval = 6 * 3600,
  -- the store certificates
  storage_adapter = "shm",
  -- the storage config passed to storage adapter
  storage_config = {
    shm_name = 'acme',
  },
  -- the challenge types enabled
  enabled_challenge_handlers = { 'http-01' },
  -- time to wait before signaling ACME server to validate in seconds
  challenge_start_delay = 0,
}

local domain_pkeys = {}

local domain_key_types, domain_key_types_count
local domain_whitelist, domain_whitelist_callback

--[[
  certs_cache = {
    rsa = {
      LRUCACHE
    },
  }
]]
local certs_cache = {}
local CERTS_CACHE_TTL = 3600
local CERTS_CACHE_NEG_TTL = 5


local update_cert_lock_key_prefix = "update_lock:"
local domain_cache_key_prefix = "domain:"
local account_private_key_prefix = "account_key:"

-- get cert from storage
local function get_certkey(domain, typ)
  local domain_key = domain_cache_key_prefix .. typ .. ":" .. domain
  local serialized, err = AUTOSSL.storage:get(domain_key)
  if err then
    return nil, "failed to read from storage err: " .. err
  end
  if not serialized then
    -- not found
    return nil, nil -- silently ignored
  end

  local deserialized = json.decode(serialized)
  if not deserialized then
    return nil, "failed to deserialize cert key from storage"
  end
  return deserialized, nil
end

-- get cert and key cdata with caching
local function get_certkey_parsed(domain, typ)
  local data, _ --[[stale]], _ --[[flags]] = certs_cache[typ]:get(domain)

  if data then
    return data, nil
  end

  -- pull from storage
  local cache, err_ret
  while true do -- luacheck: ignore
    local deserialized, err = get_certkey(domain, typ)
    if err then
      err_ret = "failed to read from storage err: " .. err
      break
    end
    if not deserialized then
      -- not found
      break
    end

    local pkey, err = ssl.parse_pem_priv_key(deserialized.pkey)
    if err then
      err_ret = "failed to parse PEM key from storage " .. err
      break
    end
    local cert, err = ssl.parse_pem_cert(deserialized.cert)
    if err then
      err_ret = "failed to parse PEM cert from storage " .. err
      break
    end
    cache = {
      pkey = pkey,
      cert = cert
    }
    break
  end
  -- fill in local cache
  if cache then
    certs_cache[typ]:set(domain, cache, CERTS_CACHE_TTL)
  else
    certs_cache[typ]:set(domain, null, CERTS_CACHE_NEG_TTL)
  end
  return cache, err_ret
end

local function update_cert_handler(data)
  log(ngx_DEBUG, "run update_cert_handler")

  local domain = data.domain
  local typ = data.type
  local domain_cache_key = domain_cache_key_prefix .. typ .. ":" .. domain
  local pkey

  if data.renew then
    local certkey, err = get_certkey(domain, typ)
    if err then
      log(ngx_ERR, "failed to read ", typ, " cert for domain: ", err)
    elseif not certkey or certkey == null then
      log(ngx_INFO, "trying to renew ", typ, " cert for domain which does not exist, creating new one")
    else
      pkey = certkey.pkey
    end
  else
    -- if defined, use the global (single) domain key
    pkey = domain_pkeys[typ]
  end

  log(ngx_INFO, "order ", typ, " cert for ", domain)

  if not pkey then
    local t = ngx.now()
    if typ == 'rsa' then
      pkey = util.create_pkey(4096, 'RSA')
    elseif typ == 'ecc' then
      pkey = util.create_pkey(nil, 'EC', 'prime256v1')
    else
      return "unknown key type: " .. typ
    end
    ngx.update_time()
    log(ngx_INFO, ngx.now() - t,  "s spent in creating new ", typ, " private key")
  end
  local cert, err = AUTOSSL.client:order_certificate(pkey, domain)
  if err then
    log(ngx_ERR, "error updating cert for ", domain, " err: ", err)
    return err
  end

  local serialized = json.encode({
    domain = domain,
    pkey = pkey,
    cert = cert,
    type = typ,
    updated = ngx.now(),
  })

  local err = AUTOSSL.storage:set(domain_cache_key, serialized)
  if err then
    log(ngx_ERR, "error storing cert and key to storage ", err)
    return err
  end

  log(ngx_INFO, "new ", typ, " cert for ", domain, " is saved")

end

-- locked wrapper for update_cert_handler
function AUTOSSL.update_cert(data)
  if not AUTOSSL.client_initialized then
    local err = AUTOSSL.client:init()
    if err then
      log(ngx_ERR, "error during acme init: ", err)
      return
    end
    local _ --[[kid]], err = AUTOSSL.client:new_account()
    if err then
      log(ngx_ERR, "error during acme login: ", err)
      return
    end
    AUTOSSL.client_initialized = true
  end

  if not AUTOSSL.is_domain_whitelisted(data.domain, true) then
    return "cert update is not allowed for domain " .. data.domain
  end

  -- Note that we lock regardless of key types
  -- Let's encrypt tends to have a (undocumented?) behaviour that if
  -- you submit an order with different CSR while the previous order is still pending
  -- you will get the previous order (with `expires` capped to an integer second).
  local lock_key = update_cert_lock_key_prefix .. ":" .. data.domain
  local err = AUTOSSL.storage:add(lock_key, "1", CERTS_CACHE_NEG_TTL)
  if err then
    ngx.log(ngx.INFO,
      "update is already running (lock key ", lock_key, " exists), current type ", data.type)
    return nil
  end

  err = update_cert_handler(data)

  -- yes we don't release lock, but wait it to expire after negative cache is cleared
  return err
end

function AUTOSSL.check_renew()
  local now = ngx.now()
  local interval = AUTOSSL.config.renew_check_interval
  if ((now - now % interval) / interval) % ngx.worker.count() ~= ngx.worker.id() then
    return
  end

  local keys = AUTOSSL.storage:list(domain_cache_key_prefix)
  for _, key in ipairs(keys) do
    local serialized, err = AUTOSSL.storage:get(key)
    if err or not serialized then
      log(ngx_WARN, "failed to renew cert, expected domain not found in storage or err " .. (err or "nil"))
      goto continue
    end

    local deserialized = json.decode(serialized)
    if not deserialized.cert then
      log(ngx_WARN, "failed to read existing cert from storage, skipping")
      goto continue
    end

    local cert = openssl.x509.new(deserialized.cert)
    local _, not_after = cert:get_lifetime()
    if not_after - now < AUTOSSL.config.renew_threshold then
      local domain = deserialized.domain
      local err = AUTOSSL.update_cert({
        domain = domain,
        renew = true,
        tries = 0,
        type = deserialized.type,
      })

      if err then
        log(ngx_ERR, "failed to renew certificate for domain ", domain, " error: ", err)
      else
        log(ngx_INFO, "successfully renewed ", deserialized.type, " cert for domain ", domain)
      end
    end

::continue::
  end
end

function AUTOSSL.init(autossl_config, acme_config)
  autossl_config = setmetatable(autossl_config or {}, { __index = default_config })

  if not autossl_config.tos_accepted then
    error("tos_accepted must be set to true to continue, to read the full term of "..
          "service, see https://letsencrypt.org/repository/"
    )
  end

  local acme_config = acme_config or {}

  if not autossl_config.storage_adapter:find("%.") then
    autossl_config.storage_adapter = "resty.acme.storage." .. autossl_config.storage_adapter
  end

  acme_config.storage_adapter = autossl_config.storage_adapter
  acme_config.storage_config = autossl_config.storage_config

  if autossl_config.account_key_path then
    acme_config.account_key = AUTOSSL.load_account_key(autossl_config.account_key_path)
  else
    -- We always generate a key here incase there isn't already one in storage
    -- that way a consistent one can be shared across all workers
    AUTOSSL.generated_account_key = AUTOSSL.create_account_key()
  end

  if autossl_config.staging then
    acme_config.api_uri = "https://acme-staging-v02.api.letsencrypt.org/directory"
  end
  acme_config.account_email = autossl_config.account_email
  acme_config.enabled_challenge_handlers = autossl_config.enabled_challenge_handlers

  acme_config.challenge_start_callback = function()
    ngx.sleep(autossl_config.challenge_start_delay)
    return true
  end

  -- cache in global variable
  domain_key_types = autossl_config.domain_key_types
  domain_key_types_count = #domain_key_types
  domain_whitelist = autossl_config.domain_whitelist
  if domain_whitelist then
    -- convert array part to map for better searching performance
    for _, w in ipairs(domain_whitelist) do
      domain_whitelist[w] = true
    end
  end
  domain_whitelist_callback = autossl_config.domain_whitelist_callback
  if domain_whitelist_callback and type(domain_whitelist_callback) ~= "function" then
    error("domain_whitelist_callback must be a function, got " .. type(domain_whitelist_callback))
  end

  if not domain_whitelist and not domain_whitelist_callback then
    ngx.log(ngx.WARN, "neither domain_whitelist or domain_whitelist_callback is defined, this may cause",
                      "security issues as all SNI will trigger a creation of certificate")
  end

  for _, typ in ipairs(domain_key_types) do
    if autossl_config.domain_key_paths[typ] then
      local domain_key_f, err = io.open(autossl_config.domain_key_paths[typ])
      if err then
        error("failed to open domain_key: " .. err)
      end
      local domain_key_pem, err = domain_key_f:read("*a")
      if err then
        error("failed to read domain key: " .. err)
      end
      domain_key_f:close()
      -- sanity check of the pem content, will error out if it's invalid
      assert(openssl.pkey.new(domain_key_pem))
      domain_pkeys[typ] = domain_key_pem
    end
    -- initialize worker cache table
    certs_cache[typ] = lrucache.new(autossl_config.cache_size)
  end

  local client, err = acme.new(acme_config)

  if err then
    error("failed to initialize ACME client: " .. err)
  end

  AUTOSSL.client = client
  AUTOSSL.client_initialized = false
  AUTOSSL.config = autossl_config
end

function AUTOSSL.init_worker()
  -- TODO: catch error and return gracefully
  local storagemod = require(AUTOSSL.config.storage_adapter)
  local storage, err = storagemod.new(AUTOSSL.config.storage_config)
  if err then
    error("failed to initialize storage: " .. err)
  end
  AUTOSSL.storage = storage

  if not AUTOSSL.config.account_key_path then
    local account_key, err = AUTOSSL.load_account_key_storage()
    if err then
      error("failed to load account key from storage: " .. err)
    end
    local _, err = AUTOSSL.client:set_account_key(account_key)
    if err then
      error("failed to set account key: " .. err)
    end
  end

  ngx.timer.every(AUTOSSL.config.renew_check_interval, AUTOSSL.check_renew)
end

function AUTOSSL.serve_http_challenge()
  AUTOSSL.client:serve_http_challenge()
end

function AUTOSSL.serve_tls_alpn_challenge()
  AUTOSSL.client:serve_tls_alpn_challenge()
end

function AUTOSSL.is_domain_whitelisted(domain, is_new_cert_needed)
  if domain_whitelist_callback then
    return domain_whitelist_callback(domain, is_new_cert_needed)
  elseif domain_whitelist then
    return domain_whitelist[domain]
  else
    return true
  end
end

function AUTOSSL.ssl_certificate()
  local domain, err = ssl.server_name()

  if err or not domain then
    log(ngx_INFO, "ignore domain ", domain, ", err: ", err)
    return
  end

  domain = string.lower(domain)

  if not AUTOSSL.is_domain_whitelisted(domain, false) then
    log(ngx_INFO, "domain ", domain, " not in whitelist, skipping")
    return
  end

  local chains_set_count = 0
  local chains_set = {}

  for i, typ in ipairs(domain_key_types) do
    local certkey, err = get_certkey_parsed(domain, typ)
    if err then
      log(ngx_ERR, "can't read key and cert from storage ", err)
    elseif certkey == null then
      log(ngx_DEBUG, "negative cached domain cert")
    elseif certkey then
      if chains_set_count == 0 then
        ssl.clear_certs()
        chains_set_count = chains_set_count + 1
      end
      chains_set[i] = true

      log(ngx_DEBUG, "set ", typ, " key for domain ", domain)
      ssl.set_cert(certkey.cert)
      ssl.set_priv_key(certkey.pkey)
    end
  end

  if domain_key_types_count ~= chains_set then
    ngx.timer.at(0, function()
      for i, typ in ipairs(domain_key_types) do
        if not chains_set[i] then
          local err = AUTOSSL.update_cert({
            domain = domain,
            renew = false,
            tries = 0,
            type = typ,
          })

          if err then
            log(ngx_ERR, "failed to create ", typ, " certificate for domain ", domain, ": ", err)
          end
        end
      end
    end)
    -- serve fallback cert this time
    return
  end
end

function AUTOSSL.create_account_key()
  local t = ngx.now()
  local pkey = util.create_pkey(4096, 'RSA')
  ngx.update_time()
  log(ngx_INFO, ngx.now() - t,  "s spent in creating new account key")
  return pkey
end

function AUTOSSL.load_account_key_storage()
  local storage = AUTOSSL.storage
  local pkey, err = storage:get(account_private_key_prefix)
  if err then
    return nil, "Failed to read account key from storage: " .. err
  end

  if not pkey then
    local err = storage:set(account_private_key_prefix, AUTOSSL.generated_account_key)
    if err then
      return nil, "failed to save account_key: " .. err
    end
    return AUTOSSL.generated_account_key, nil
  end
  return pkey, nil
end

function AUTOSSL.load_account_key(filepath)
  local account_key_f, err = io.open(filepath)
  if err then
    error("can't open account_key file " .. filepath .. ": " .. err)
  end
  local account_key_pem, err = account_key_f:read("*a")
  if err then
    error("can't read account_key file " .. filepath .. ": " .. err)
  end
  account_key_f:close()
  return account_key_pem
end

function AUTOSSL.get_certkey(domain, typ)
  if type(domain) ~= "string" then
    error("domain must be a string")
  end

  return get_certkey(domain, typ or "rsa")
end

return AUTOSSL
