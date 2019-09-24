local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_string = ffi.string

local floor = math.floor

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
local asn1_lib = require("resty.acme.crypto.openssl.asn1")
local OPENSSL_10 = require("resty.acme.crypto.openssl.version").OPENSSL_10

ffi.cdef [[
  void X509_free(X509 *a);

  EVP_PKEY *d2i_PrivateKey_bio(BIO *bp, EVP_PKEY **a);
  EVP_PKEY *d2i_PUBKEY_bio(BIO *bp, EVP_PKEY **a);
]]

local X509_get0_notBefore, X509_get0_notAfter
if OPENSSL_10 then
  ffi.cdef [[
    // crypto/x509/x509.h
    typedef struct X509_val_st {
      ASN1_TIME *notBefore;
      ASN1_TIME *notAfter;
    } X509_VAL;
    // Note: this struct is trimmed
    typedef struct x509_cinf_st {
      ASN1_INTEGER *version;
      ASN1_INTEGER *serialNumber;
      /*X509_ALGOR*/ void *signature;
      /*X509_NAME*/ void *issuer;
      X509_VAL *validity;
      // trimmed
    } X509_CINF;
    // Note: this struct is trimmed
    struct x509_st {
      X509_CINF *cert_info;
      // trimmed
    } X509;

  ]]
  X509_get0_notBefore = function(x509)
    return x509.cert_info.validity.notBefore
  end
  X509_get0_notAfter = function(x509)
    return x509.cert_info.validity.notAfter
  end
else
  ffi.cdef [[
    const ASN1_TIME *X509_get0_notBefore(const X509 *x);
    const ASN1_TIME *X509_get0_notAfter(const X509 *x);
  ]]
  X509_get0_notBefore = C.X509_get0_notBefore
  X509_get0_notAfter = C.X509_get0_notAfter
end


local _M = {}
local mt = { __index = _M, __tostring = tostring }

-- only PEM format is supported for now
function _M.new(cert)
  if type(cert) ~= "string" then
    return nil, "expect a string at #1"
  end
  local bio = C.BIO_new_mem_buf(cert, #cert)
  if bio == nil then
    return nil, "BIO_new_mem_buf() failed"
  end

  local ctx = C.PEM_read_bio_X509(bio, nil, nil, nil)
  if ctx == nil then
    C.BIO_free(bio)
    return nil, "PEM_read_bio_X509() failed"
  end

  C.BIO_free(bio)
  ffi_gc(ctx, C.X509_free)

  local self = setmetatable({
    ctx = ctx,
  }, mt)

  return self, nil
end

-- https://github.com/wahern/luaossl/blob/master/src/openssl.c
local function isleap(year)
	return (year % 4) == 0 and ((year % 100) > 0 or (year % 400) == 0)
end

local past = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
local function yday(year, mon, mday)
	local d = past[mon] + mday - 1
  if mon > 1 and isleap(year) then
    d = d + 1
  end
	return d
end

local function leaps(year)
  return floor(year / 400) + floor(year / 4) - floor(year / 100)
end

local function asn1_to_unix(asn1)
  local s = asn1_lib.ASN1_STRING_get0_data(asn1)
  local s = ffi.string(s)
  -- 190303223958Z
  local year = 2000 + tonumber(s:sub(1, 2))
  local month = tonumber(s:sub(3, 4))
  local day = tonumber(s:sub(5, 6))
  local hour = tonumber(s:sub(7, 8))
  local minute = tonumber(s:sub(9, 10))
  local second = tonumber(s:sub(11, 12))

  local tm = 0
  tm = (year - 1970) * 365
  tm = tm + leaps(year - 1) - leaps(1969)
  tm = (tm + yday(year, month, day)) * 24
  tm = (tm + hour) * 60
  tm = (tm + minute) * 60
  tm = tm + second
  return tm
end

function _M:getLifetime()
  local err
  local not_before = X509_get0_notBefore(self.ctx)
  if not_before == nil then
    return nil, nil, "X509_get_notBefore() failed"
  end
  not_before = asn1_to_unix(not_before)
  local not_after = X509_get0_notAfter(self.ctx)
  if not_after == nil then
    return nil, nil, "X509_get_notAfter() failed"
  end
  not_after = asn1_to_unix(not_after)

  return not_before, not_after, nil
end

return _M
