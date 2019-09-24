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
  local version_num = require("resty.acme.crypto.openssl.version").version_num
  if not version_num or version_num < 0x10000000 then
    error(string.format("OpenSSL version %x is not supported", version_num or 0))
  end

  ngx.log(ngx.INFO, "using ffi, OpenSSL version linked: ", string.format("%x", version_num))
  return {
    pkey = require("resty.acme.crypto.openssl.pkey"),
    x509 = require("resty.acme.crypto.openssl.x509"),
    name = require("resty.acme.crypto.openssl.x509.name"),
    altname = require("resty.acme.crypto.openssl.x509.altname"),
    csr = require("resty.acme.crypto.openssl.x509.csr"),
    digest = require("resty.acme.crypto.openssl.digest")
  }
end
