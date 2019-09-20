local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  RSA *RSA_new(void);
  void RSA_free(RSA *r);
  int RSA_generate_key_ex(RSA *rsa, int bits, BIGNUM *e, BN_GENCB *cb);
  void RSA_get0_key(const RSA *r,
                  const BIGNUM **n, const BIGNUM **e, const BIGNUM **d);
  void RSA_get0_factors(const RSA *r, const BIGNUM **p, const BIGNUM **q);
]]