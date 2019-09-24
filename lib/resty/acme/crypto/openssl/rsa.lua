local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
local OPENSSL_10 = require("resty.acme.crypto.openssl.version").OPENSSL_10

ffi.cdef [[
  RSA *RSA_new(void);
  void RSA_free(RSA *r);
  int RSA_generate_key_ex(RSA *rsa, int bits, BIGNUM *e, BN_GENCB *cb);
  void RSA_get0_key(const RSA *r,
                  const BIGNUM **n, const BIGNUM **e, const BIGNUM **d);
  void RSA_get0_factors(const RSA *r, const BIGNUM **p, const BIGNUM **q);
]]

if OPENSSL_10 then
  ffi.cdef [[
    // crypto/rsa/rsa_locl.h
    // Note: this struct is trimmed
    struct rsa_st {
      int pad;
      // the following has been changed in OpenSSL 1.1.x to int32_t
      long version;
      const RSA_METHOD *meth;
      ENGINE *engine;
      BIGNUM *n;
      BIGNUM *e;
      BIGNUM *d;
      BIGNUM *p;
      BIGNUM *q;
      BIGNUM *dmp1;
      BIGNUM *dmq1;
      BIGNUM *iqmp;
      // trimmed

      // CRYPTO_EX_DATA ex_data;
      // int references;
      // int flags;
      // BN_MONT_CTX *_method_mod_n;
      // BN_MONT_CTX *_method_mod_p;
      // BN_MONT_CTX *_method_mod_q;

      // char *bignum_data;
      // BN_BLINDING *blinding;
      // BN_BLINDING *mt_blinding;
    };
  ]]
else
  ffi.cdef('struct rsa_st;')
end