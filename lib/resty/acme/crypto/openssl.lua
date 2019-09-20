local ok, _ = pcall(require, "openssl.pkey")
if ok then
  ngx.log(ngx.INFO, "using luaossl")
  return {
    pkey = require("openssl.pkey"),
    x509 = require("openssl.x509"),
    name = require("openssl.x509.name"),
    altname = require("openssl.x509.altname"),
    csr = require("openssl.x509.csr"),
    digest = require("openssl.digest")
  }
else
  ngx.log(ngx.INFO, "using ffi")
  return {
    pkey = require("resty.acme.crypto.openssl.pkey"),
    x509 = require("resty.acme.crypto.openssl.x509"),
    name = require("resty.acme.crypto.openssl.x509.name"),
    altname = require("resty.acme.crypto.openssl.x509.altname"),
    csr = require("resty.acme.crypto.openssl.x509.csr"),
    digest = require("resty.acme.crypto.openssl.digest")
  }
end
