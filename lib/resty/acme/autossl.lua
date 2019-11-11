local lrucache = require "resty.lrucache"
local acme = require "resty.acme.client"
local util = require "resty.acme.util"
local openssl = require("resty.acme.openssl")
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

local account_key
local domain_pkeys = {}

local domain_key_types, domain_key_types_count
local domain_whitelist

local ev, events

--[[
  certs_cache = {
    rsa = {
      LRUCACHE
    },
  }
]]
local certs_cache = {}

local domain_cache_key_prefix = "domain:"

local function update_cert_handler(data, event, source, pid)
  log(ngx_DEBUG, "run update_cert_handler")

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
      pkeys = certkey.pkey
    end
  else
    -- if defined, use the global (single) domain key
    pkey = domain_pkeys[typ]
  end

  log(ngx_INFO, "order ", typ, " cert for ", domain)

  local pkey, cert, err = AUTOSSL.update_cert(pkey, domain, typ)
  if err then
    log(ngx_ERR, "error updating cert for ", domain, " err: ", err)
    -- put it back for retry
    ngx.timer.at(60, function()
      data.tries = data.tries + 1
      local unique = domain .. "#" .. data.tries
      local _, err = ev.post(events._source, events.update_cert, data, unique)
      if err then
        log(ngx_ERR, "error putting back events queue ", err)
      end
    end)
    return
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
    return
  end

  local sucess, err = ev.post(events._source, events.cache_invalidation, {
    domain = domain,
    type = typ,
  }, nil)
  if err then
    log(ngx_ERR, "failed to post cache invalidation event ", err)
    return
  end

end

local function cache_invalidation_handler(data, event, source, pid)
  log(ngx_DEBUG, "run cache_invalidation_handler")

  local typ = data.type
  local domain = data.domain
  if not typ or not domain then
    log(ngx_WARN, "received cache_invalidation event with no type or domain defined")
    return
  end

  certs_cache[data.type]:delete(data.domain)
end

-- get cert and key cdata with caching
local function get_certkey(domain, typ)
  local data, --[[stale--]]_, flags = certs_cache[typ]:get(domain)
  if data then
    return data, nil
  end
  -- pull from storage
  local domain_cache_key = domain_cache_key_prefix .. typ .. ":" .. domain
  local serialized, err = AUTOSSL.storage:get(domain_cache_key)
  if err then
    return nil, "failed to read from storage err: " .. err
  end

  if not serialized then
    certs_cache[typ]:set(domain, null)
    return nil, nil
  end

  local deserialized = json.decode(serialized)
  if not deserialized then
    return nil, "failed to deserialize cert key from storage"
  end

  local pkey, err = ssl.parse_pem_priv_key(deserialized.pkey)
  if err then
    return nil, "failed to parse PEM key from storage " .. err
  end
  local cert, err = ssl.parse_pem_cert(deserialized.cert)
  if err then
    return nil, "failed to parse PEM cert from storage " .. err
  end
  local cache = {
    pkey = pkey,
    cert = cert
  }
  -- fill in local cache
  certs_cache[typ]:set(domain, cache)
  return cache, nil
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
      local sucess, err = ev.post(events._source, events.update_cert, {
        domain = domain,
        renew = true,
        tries = 0,
        type = deserialized.type,
      }, "renew:" .. deserialized.type .. ":" .. domain)

      if err then
        log(ngx_ERR, "failed to renew certificate for domain ", domain)
      elseif success == 'done' then
        log(ngx_INFO, "renewed certificate for domain ", domain)
      else -- recursive
        log(ngx_INFO, "renewal of cert for ", domain, " is already running: ", success)
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

  acme_config.account_key = AUTOSSL.load_account_key(autossl_config.account_key_path)
  if autossl_config.staging then
    acme_config.api_uri = "https://acme-staging-v02.api.letsencrypt.org"
  end
  acme_config.account_email = autossl_config.account_email

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

  for _, typ in ipairs(domain_key_types) do
    if autossl_config.domain_key_paths[typ] then
      local domain_key_f, err = io.open(autossl_config.domain_key_paths[typ])
      if err then
        error(err)
      end
      local domain_key_pem, err = domain_key_f:read("*a")
      if err then
        error(err)
      end
      domain_key_f:close()
      -- sanity check of the pem content, will error out if it's invalid
      openssl.pkey.new(domain_key_pem)
      domain_pkeys[typ] = domain_key_pem
    end
    -- initialize worker cache table
    certs_cache[typ] = lrucache.new(autossl_config.cache_size)
  end

  local client, err = acme.new(acme_config)

  if err then
    error(err)
  end

  if not autossl_config.storage_adapter:find("resty.acme.storage.") then
    autossl_config.storage_adapter = "resty.acme.storage." .. autossl_config.storage_adapter
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
    error("failed to initialize worker events: ", err)
  end

  ev.register(update_cert_handler, events._source, events.update_cert)
  ev.register(cache_invalidation_handler, events._source, events.cache_invalidation)

  ngx.timer.every(AUTOSSL.config.renew_check_interval, AUTOSSL.check_renew)
end

function AUTOSSL.serve_http_challenge()
  AUTOSSL.client:serve_http_challenge()
end

function AUTOSSL.update_cert(pkey, domain, typ)
  local pkey = pkey
  if not pkey then
    local t = ngx.now()
    if typ == 'rsa' then
      pkey = util.create_pkey(4096, 'RSA')
    elseif typ == 'ecc' then
      pkey = util.create_pkey(nil, 'EC', 'prime256v1')
    else
      return nil, nil, "unknown key type: " .. typ
    end
    ngx.update_time()
    log(ngx_INFO, ngx.now() - t,  "s spent in creating new ", typ, " private key")
  end
  local cert, err = AUTOSSL.client:order_certificate(pkey, domain)
  if err then
    return nil, nil, err
  end
  return pkey, cert, err
end


function AUTOSSL.ssl_certificate()
  local domain, err = ssl.server_name()

  if err or not domain then
    log(ngx_INFO, "ignore domain ", domain, ", err: ", err)
    return
  end
  if domain_whitelist and not domain_whitelist[domain] then
    log(ngx_INFO, "domain ", domain, " not in whitelist, skipping")
    return
  end

  local chains_set_count = 0
  local chains_set = {}

  -- TODO: worker level cache
  for i, typ in ipairs(domain_key_types) do
    local certkey, err = get_certkey(domain, typ)
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
          local sucess, err = ev.post(events._source, events.update_cert, {
            domain = domain,
            tries = 0,
            type = typ,
          }, typ .. ":" .. domain)

          if err then
            log(ngx_ERR, "failed to create certificate for domain ", domain)
          elseif success == 'done' then
            log(ngx_INFO, "created certificate for domain ", domain)
          else -- recursive
            log(ngx_INFO, "creation of cert for ", domain, " is already running: ", success)
          end
        end
      end
    end)
    -- serve fallback cert this time
    return
  end
end

function AUTOSSL.load_account_key(filepath)
  if not filepath then
    local t = ngx.now()
    local pkey = util.create_pkey(4096, 'RSA')
    ngx.update_time()
    log(ngx_INFO, ngx.now() - t,  "s spent in creating new account key")
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
