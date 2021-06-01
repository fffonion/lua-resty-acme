local ffi = require("ffi")
local ssl = require "ngx.ssl"

local pkey = require("resty.openssl.pkey")
local digest = require("resty.openssl.digest")
local x509 = require("resty.openssl.x509")
local altname = require("resty.openssl.x509.altname")
local extension = require("resty.openssl.x509.extension")
local objects = require("resty.openssl.objects")
local ssl_ctx = require("resty.openssl.ssl_ctx")


local _M = {}
local mt = {__index = _M}

-- Ref: https://tools.ietf.org/html/draft-ietf-acme-tls-alpn-07

-- local ssl_find_proto_acme_tls = function(client_alpn)
--   local len = 1
--   local acme_found
--   while len < #client_alpn do
--     local i = string.byte(sub(client_alpn, len, len+1))
--     local proto = sub(client_alpn, len+1, len+2+i)
--     if proto == acme_protocol_name then
--       acme_found = true
--       break
--     end
--     len = len + i + 1
--   end
--   return acme_found
-- end

local acme_protocol_name_wire = '\010acme-tls/1'

local alpn_select_cb = ffi.cast("SSL_CTX_alpn_select_cb_func", function(_, out, outlen, client, client_len)
  local code = ffi.C.SSL_select_next_proto(
    ffi.cast("unsigned char **", out), outlen,
    acme_protocol_name_wire, 10,
    client, client_len)
  if code ~= 1 then -- OPENSSL_NPN_NEGOTIATED
    return 3 -- SSL_TLSEXT_ERR_NOACK
  end
  return 0 -- SSL_TLSEXT_ERR_OK
end)

local function inject_tls_alpn()
  local ssl_ctx, err = ssl_ctx.from_request()
  if err then
    ngx.log(ngx.WARN, "inject_tls_alpn: ", err)
    return
  end
  ffi.C.SSL_CTX_set_alpn_select_cb(ssl_ctx.ctx, alpn_select_cb, nil)
  return true
end

function _M.new(storage)
  local self = setmetatable({
    storage = storage,
  }, mt)
  return self
end

local function ch_key(challenge)
  return challenge .. "#tls-alpn-01"
end


function _M:register_challenge(_, response, domains)
  local err
  for _, domain in ipairs(domains) do
    err = self.storage:set(ch_key(domain), response, 3600)
    if err then
      return err
    end
  end
end

function _M:cleanup_challenge(_--[[challenge]], domains)
  local err
  for _, domain in ipairs(domains) do
    err = self.storage:delete(ch_key(domain))
    if err then
      return err
    end
  end
end

local id_pe_acmeIdentifier = "1.3.6.1.5.5.7.1.31"
local nid = objects.txt2nid(id_pe_acmeIdentifier)
if not nid or nid == 0 then
  nid = objects.create(
    id_pe_acmeIdentifier, -- nid
    "pe-acmeIdentifier",  -- sn
    "ACME Identifier"     -- ln
  )
end

local function serve_challenge_cert(self)
  local domain = assert(ssl.server_name())
  local challenge, err = self.storage:get(ch_key(domain))
  if err then
    ngx.log(ngx.ERR, "error getting challenge response from storage ", err)
    ngx.exit(500)
  end

  if not challenge then
    ngx.log(ngx.WARN, "no corresponding response found for ", domain)
    ngx.exit(404)
  end

  local dgst = assert(digest.new("sha256"):final(challenge))
  -- 0x04: OCTET STRING
  -- 0x20: length
  dgst = "DER:0420" .. dgst:gsub("(.)", function(s) return string.format("%02x", string.byte(s)) end)
  ngx.log(ngx.DEBUG, "token: ", challenge, ", digest: ", dgst)

  local key = pkey.new()
  local cert = x509.new()
  cert:set_pubkey(key)
  local ext = assert(extension.new(nid, dgst))
  ext:set_critical(true)
  cert:add_extension(ext)

  local alt = assert(altname.new():add(
    "DNS", domain
  ))
  assert(cert:set_subject_alt_name(alt))
  cert:sign(key)

  local key_ct = assert(ssl.parse_pem_priv_key(key:to_PEM("private")))
  local cert_ct = assert(ssl.parse_pem_cert(cert:to_PEM()))

  ssl.clear_certs()
  assert(ssl.set_cert(cert_ct))
  assert(ssl.set_priv_key(key_ct))

  ngx.log(ngx.DEBUG, "served tls-alpn challenge")
end

function _M:serve_challenge()
  if ngx.config.subsystem ~= "stream" then
    ngx.log(ngx.ERR, "tls-apln-01 challenge can't be used in ", ngx.config.subsystem, " subsystem")
    ngx.exit(500)
  end

  local phase = ngx.get_phase()
  if phase == "ssl_cert" then
    if inject_tls_alpn() then
      serve_challenge_cert(self)
    end
  else
    ngx.log(ngx.ERR, "tls-apln-01 challenge don't know what to do in ", phase, " phase")
    ngx.exit(500)
  end
end

return _M
