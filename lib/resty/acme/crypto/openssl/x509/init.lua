local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_string = ffi.string

local floor = math.floor

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
require "resty.acme.crypto.openssl.asn1"

ffi.cdef [[
  void X509_free(X509 *a);
  const ASN1_TIME *X509_get0_notBefore(const X509 *x);
  const ASN1_TIME *X509_get0_notAfter(const X509 *x);
]]

local _M = {}
local mt = { __index = _M, __tostring = tostring }

function _M.new(cert)
  local bio = C.BIO_new_mem_buf(cert, #cert)
  if not bio then
    return nil, "BIO_new_mem_buf() failed"
  end

  local ctx = C.PEM_read_bio_X509(bio, nil, nil, nil)
  if not ctx then
    return nil, "PEM_read_bio_X509() failed"
  end

  C.BIO_free(bio)
  ffi_gc(ctx, C.X509_free)

  local self = setmetatable({
    ctx = ctx,
  }, mt)

  return self, nil
end

-- stealed from https://github.com/wahern/luaossl/blob/master/src/openssl.c
function isleap(year)
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
  local s = C.ASN1_STRING_get0_data(asn1)
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
  local not_before = C.X509_get0_notBefore(self.ctx)
  if not not_before then
    return nil, nil, "X509_get_notBefore() failed"
  end
  not_before = asn1_to_unix(not_before)
  local not_after = C.X509_get0_notAfter(self.ctx)
  if not not_after then
    return nil, nil, "X509_get_notAfter() failed"
  end
  not_after = asn1_to_unix(not_after)

  return not_before, not_after, nil
end

return _M
