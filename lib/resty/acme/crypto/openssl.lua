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
  -- stealed from https://github.com/GUI/lua-openssl-ffi/blob/master/lib/openssl-ffi/version.lua
  local ffi = require "ffi"
  local C = ffi.C

  ffi.cdef[[
    unsigned long OpenSSL_version_num();
  ]]
  local ok, version_num = pcall(function()
    return C.OpenSSL_version_num();
  end)

  if not ok then
    error("ffi openssl only supports OpenSSL >= 1.1. Please install luaossl or link Openresty with libssl1.1.")
  end
  ngx.log(ngx.INFO, "using ffi, openssl version linked: ", string.format("%x", tonumber(version_num)))
  return {
    pkey = require("resty.acme.crypto.openssl.pkey"),
    x509 = require("resty.acme.crypto.openssl.x509"),
    name = require("resty.acme.crypto.openssl.x509.name"),
    altname = require("resty.acme.crypto.openssl.x509.altname"),
    csr = require("resty.acme.crypto.openssl.x509.csr"),
    digest = require("resty.acme.crypto.openssl.digest")
  }
end
