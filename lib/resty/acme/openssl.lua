local ok, ret = pcall(require, "resty.openssl")

if ok then
    local openssl = ret
    ngx.log(ngx.INFO, "using ffi, OpenSSL version linked: ", string.format("%x", openssl.version.version_num))

    return {
      pkey = require("resty.openssl.pkey"),
      x509 = require("resty.openssl.x509"),
      name = require("resty.openssl.x509.name"),
      altname = require("resty.openssl.x509.altname"),
      csr = require("resty.openssl.x509.csr"),
      digest = require("resty.openssl.digest")
    }
end
error(ret)
ngx.log(ngx.ERR, "resty.openssl doesn't load: ", ret)

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
end

error("no openssl binding is usable or installed, requires either lua-resty-openssl or luaossl")

