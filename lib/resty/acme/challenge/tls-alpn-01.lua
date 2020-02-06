local ffi = require("ffi")
local sub = string.sub
local ssl = require "ngx.ssl"

local pkey = require("resty.openssl.pkey")
local digest = require("resty.openssl.digest")
local x509 = require("resty.openssl.x509")
local altname = require("resty.openssl.x509.altname")
local extension = require("resty.openssl.x509.extension")
local objects = require("resty.openssl.objects")


local _M = {}
local mt = {__index = _M}

-- Ref: https://tools.ietf.org/html/draft-ietf-acme-tls-alpn-07


ffi.cdef [[
  typedef long off_t;
  typedef unsigned int socklen_t; // windows uses int, same size
  typedef unsigned short in_port_t;

  typedef struct ssl_st SSL;
  typedef struct ssl_ctx_st SSL_CTX;

  typedef long (*ngx_recv_pt)(void *c, void *buf, size_t size);
  typedef long (*ngx_recv_chain_pt)(void *c, void *in,
      off_t limit);
  typedef long (*ngx_send_pt)(void *c, void *buf, size_t size);
  typedef void *(*ngx_send_chain_pt)(void *c, void *in,
      off_t limit);

  typedef struct {
    size_t             len;
    void               *data;
  } ngx_str_t;

  typedef struct {
    SSL             *connection;
    SSL_CTX         *session_ctx;
    // trimmed
  } ngx_ssl_connection_s;

  typedef struct {
    void               *data;
    void               *read;
    void               *write;

    int                 fd;

    ngx_recv_pt         recv;
    ngx_send_pt         send;
    ngx_recv_chain_pt   recv_chain;
    ngx_send_chain_pt   send_chain;

    void               *listening;

    off_t               sent;

    void               *log;

    void               *pool;

    int                 type;

    void                *sockaddr;
    socklen_t           socklen;
    ngx_str_t           addr_text;

    ngx_str_t           proxy_protocol_addr;
    in_port_t           proxy_protocol_port;

    ngx_ssl_connection_s  *ssl;
    // trimmed
  } ngx_connection_s;

  typedef struct {
      ngx_connection_s                     *connection;
      // trimmed
  } ngx_stream_lua_request_s;

  typedef struct {
    unsigned int                     signature;         /* "HTTP" */

    ngx_connection_s                 *connection;
    // trimmed
  } ngx_http_request_s;

  typedef int (*SSL_CTX_alpn_select_cb_func)(SSL *ssl,
                                           const unsigned char **out,
                                           unsigned char *outlen,
                                           const unsigned char *in,
                                           unsigned int inlen,
                                           void *arg);

  void SSL_CTX_set_alpn_select_cb(SSL_CTX *ctx,
                                           SSL_CTX_alpn_select_cb_func cb,
                                           void *arg);

  int SSL_select_next_proto(unsigned char **out, unsigned char *outlen,
                           const unsigned char *server,
                           unsigned int server_len,
                           const unsigned char *client,
                           unsigned int client_len);
]]

local get_request
do
    local ok, exdata = pcall(require, "thread.exdata")
    if ok and exdata then
        function get_request()
            local r = exdata()
            if r ~= nil then
                return r
            end
        end

    elseif false then
        local getfenv = getfenv

        function get_request()
            return getfenv(0).__ngx_req
        end
    end
end

local ssl_find_proto_acme_tls = function(client_alpn)
  local len = 1
  local acme_found
  while len < #client_alpn do
    local i = string.byte(sub(client_alpn, len, len+1))
    local proto = sub(client_alpn, len+1, len+2+i)
    if proto == acme_protocol_name then
      acme_found = true
      break
    end
    len = len + i + 1
  end
  return acme_found
end

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
  local c = get_request()
  if ngx.config.subsystem == "stream" then
    c = ffi.cast("ngx_stream_lua_request_s*", c)
  else -- http
    c = ffi.cast("ngx_http_request_s*", c)
  end

  local ngx_ssl = c.connection.ssl
  if ngx_ssl == nil then
    ngx.log(ngx.WARN, "inject_tls_alpn: no ssl")
    return
  end
  local ssl_ctx = ngx_ssl.session_ctx
  ffi.C.SSL_CTX_set_alpn_select_cb(ssl_ctx, alpn_select_cb, nil)
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
