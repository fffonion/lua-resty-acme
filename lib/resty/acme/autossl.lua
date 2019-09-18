local acme = require "resty.acme.client"
local util = require "resty.acme.util"
local json = require "cjson"
local ssl = require "ngx.ssl"

local log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO

local openssl = {
  x509 = require("openssl.x509"),
  pkey = require("openssl.pkey"),
}

local AUTOSSL = {}

local default_config = {
  -- if using the let's encrypt staging API
  staging = false,
  -- the path to account private key in PEM format
  account_key_path = nil,
  -- the account email to register
  account_email = nil,
  -- the global domain private key
  domain_rsa_key_path = nil,
  -- the threshold to renew a cert before it expires, in seconds
  renew_threshold = 7 * 86400,
  -- interval to check cert renewal, in seconds
  renew_check_interval = 6 * 3600,
  -- the shm name to store worker events
  ev_shm = 'autossl_events',
  -- the store certificates
  storage_adapter = "shm",
  -- the storage config passed to storage adapter
  storage_config = {
    shm_name = 'acme',
  },
}

local account_key, domain_rsa_key

local ev, events

local domain_cache_key_prefix = "domain:"

local function update_cert_handler(data, event, source, pid)
  log(ngx_INFO, "run update_cert_handler")

  if not AUTOSSL.client_initialized then
    local err = AUTOSSL.client:init()
    if err then
      log(ngx_ERR, "error during acme init: ", err)
      return
    end
    local kid, err = AUTOSSL.client:new_account()
    if err then
      log(ngx_ERR, "error during acme login: ", err)
      return
    end
    AUTOSSL.client_initialized = true
  end

  local domain = data.domain
  local domain_cache_key = domain_cache_key_prefix .. domain

  local pkey

  if data.renew then
    local serialized, err = AUTOSSL.storage:get(domain_cache_key)
    if err then
      return nil, "can't renew cert, storage err: " .. err
    elseif not serialized then
      return nil, "can't renew cert, pkey not found in storage"
    end
    local deserialized = json.decode(serialized)
    if not deserialized.pkey then
      log(ngx_ERR, "pkey not found in previous storage, creating new cert")
    else
      pkey = deserialized.pkey
    end
  else
    -- if defined, use the global (single) domain key
    pkey = domain_rsa_key
  end

  log(ngx_INFO, "create cert for ", domain)

  local pkey, cert, err = AUTOSSL.update_cert(pkey, domain)
  if err then
    log(ngx_ERR, "error updating cert for ", domain, " err: ", err)
    -- put it back for retry
    ngx.timer.at(60, function()
      data.tries = data.tries + 1
      local unique = domain .. "#" .. data.tries
      local _, err = ev.post(events._source, events.update_cert, data, unique)
      if err then
        log(ngx_ERR, "can't putting back events queue ", err)
      end
    end)
    return
  end

  local serialized = json.encode({
    domain = domain,
    pkey = pkey,
    cert = cert,
    updated = ngx.now(),
  })

  local err = AUTOSSL.storage:set(domain_cache_key, serialized)
  if err then
    log(ngx_ERR, "error storing cert and key to storage ", err)
    return
  end

  -- TODO: worker events cache invalidation
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
      log(ngx_ERR, "can't renew cert, pkey not found in storage or err " .. (err or "nil"))
      goto continue
    end

    local deserialized = json.decode(serialized)
    if not deserialized.cert then
      log(ngx_ERR, "cert not found in previous storage, skipping")
      goto continue
    end

    local cert = openssl.x509.new(deserialized.cert)
    local _, not_after = cert:getLifetime()
    if not_after - now < AUTOSSL.config.renew_threshold then
      local sucess, err = ev.post(events._source, events.update_cert, {
        domain = deserialized.domain,
        renew = true,
        tries = 0,
      }, "renew#" .. deserialized.domain)

      if err then
        log(ngx_ERR, "failed to renew certificate for domain ", name)
      elseif success == 'done' then
        log(ngx_INFO, "renewed certificate for domain ", name)
      else -- recursive
        log(ngx_INFO, "event for domain ", name, " is already running")
      end
    end

::continue::
  end
end


local function cache_invalidation_handler(data, event, source, pid)
  log(ngx_INFO, "run cache_invalidation_handler")

  -- TODO
end

function AUTOSSL.init(autossl_config)
  autossl_config = setmetatable(autossl_config or {}, { __index = default_config })

  local acme_config = {}

  acme_config.account_key = AUTOSSL.load_account_key(autossl_config.account_key_path)
  if autossl_config.staging then
    acme_config.api_uri = "https://acme-staging-v02.api.letsencrypt.org"
  end
  acme_config.account_email = autossl_config.account_email

  if autossl_config.domain_rsa_key_path then
    local domain_rsa_key_f, err = io.open(autossl_config.domain_rsa_key_path)
    if err then
      error(err)
    end
    local domain_rsa_key_pem, err = domain_rsa_key_f:read("*a")
    if err then
      error(err)
    end
    domain_rsa_key_f:close()
    -- sanity check of the pem content, will error out if it's invalid
    openssl.pkey.new(domain_rsa_key_pem)
    domain_rsa_key = domain_rsa_key_pem
  end

  local client, err = acme.new(acme_config)

  if err then
    error(err)
  end
  
  AUTOSSL.client = client
  AUTOSSL.client_initialized = false
  AUTOSSL.config = autossl_config
end

function AUTOSSL.init_worker()
  -- TODO: catch error and return gracefully
  local storagemod = require("resty.acme.storage." .. AUTOSSL.config.storage_adapter)
  local storage, err = storagemod.new(AUTOSSL.config.storage_config)
  if err then
    error(err)
  end
  AUTOSSL.storage = storage

  ev = require "resty.worker.events"
  events = ev.event_list(
    "source",
    "update_cert",
    "cache_invalidation"
  )

  -- setup events
  local ok, err = ev.configure {
    shm = AUTOSSL.config.ev_shm,
    timeout = 60,           -- life time of unique event data in shm
    interval = 5,           -- poll interval (seconds)
  }
  if not ok then
    log(ngx_ERR, "failed to start event system: ", err)
    return
  end

  ev.register(update_cert_handler, events._source, events.update_cert)
  ev.register(cache_invalidation_handler, events._source, events.cache_invalidation)

  ngx.timer.every(AUTOSSL.config.renew_check_interval, AUTOSSL.check_renew)
end

function AUTOSSL.serve_http_challenge()
  AUTOSSL.client:serve_http_challenge()
end

function AUTOSSL.update_cert(pkey, domain)
  local pkey = pkey or util.create_pkey(4096, 'RSA')
  local cert, err = AUTOSSL.client:order_certificate(pkey, domain)
  if err then
    return nil, nil, err
  end
  return pkey, cert, err
end


function AUTOSSL.ssl_certificate()
  local name, err = ssl.server_name()

  if err or not name then
    log(ngx_INFO "ignore domain ", name, ", err: ", err)
    return
  end
  
  local serialized, err = AUTOSSL.storage:get(domain_cache_key_prefix .. name)
  if err then
    log(ngx_ERR, "can't read key and cert from storage ", err)
    return
  end

  local deserialized = serialized and json.decode(serialized)

  if not serialized or not deserialized.pkey or not deserialized.cert then
    ngx.timer.at(0, function()
      local sucess, err = ev.post(events._source, events.update_cert, {
        domain = name,
        tries = 0,
      }, name)

      if err then
        log(ngx_ERR, "failed to create certificate for domain ", name)
      elseif success == 'done' then
        log(ngx_INFO, "created certificate for domain ", name)
      else -- recursive
        log(ngx_INFO, "event for domain ", name, " is already running")
      end
    end)
    -- serve fallback cert this time
    return
  end

  ssl.clear_certs()
  -- TODO: use mlcache
  local der_cert, err = ssl.cert_pem_to_der(deserialized.cert)
  ssl.set_der_cert(der_cert)
  local der_key, err = ssl.priv_key_pem_to_der(deserialized.pkey)
  ssl.set_der_priv_key(der_key)

end

function AUTOSSL.load_account_key(filepath)
  if not filepath then
    log(ngx_INFO, "creating new account key")
    local pkey = util.create_pkey(4096, 'RSA')
    return pkey
  else
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
end

return AUTOSSL
