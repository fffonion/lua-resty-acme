local ok, ret = pcall(require, "resty.openssl")

if ok then
  local version = require("resty.openssl.version")
  ngx.log(ngx.INFO, "using ffi, OpenSSL version linked: ", string.format("%x", version.version_num))

  return {
    pkey = require("resty.openssl.pkey"),
    x509 = require("resty.openssl.x509"),
    name = require("resty.openssl.x509.name"),
    altname = require("resty.openssl.x509.altname"),
    csr = require("resty.openssl.x509.csr"),
    digest = require("resty.openssl.digest"),
    hmac = require("resty.openssl.hmac"),
  }
end

ngx.log(ngx.INFO, "resty.openssl doesn't load: ", ret)

local ok, _ = pcall(require, "openssl.pkey")
if ok then
  ngx.log(ngx.INFO, "using luaossl")
  local tb = {
    pkey = require("openssl.pkey"),
    x509 = require("openssl.x509"),
    name = require("openssl.x509.name"),
    altname = require("openssl.x509.altname"),
    csr = require("openssl.x509.csr"),
    digest = require("openssl.digest"),
    hmac = require("openssl.hmac"),
  }

  local bn = require("openssl.bignum")
  bn.to_binary = bn.toBinary

  tb.pkey.to_PEM = tb.pkey.toPEM
  tb.pkey.get_parameters = tb.pkey.getParameters

  tb.csr.set_pubkey = tb.csr.setPublicKey
  tb.csr.set_subject_name = tb.csr.setSubject
  tb.csr.set_subject_alt = tb.csr.setSubjectAlt

  tb.x509.set_lifetime = tb.x509.setLifetime
end

error("no openssl binding is usable or installed, requires either lua-resty-openssl or luaossl")

