local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  struct rsa_st;
  EVP_PKEY *EVP_PKEY_new(void);
  void EVP_PKEY_free(EVP_PKEY *pkey);
  struct rsa_st *EVP_PKEY_get0_RSA(EVP_PKEY *pkey);
  int EVP_PKEY_set1_RSA(EVP_PKEY *pkey, RSA *key);
  int EVP_PKEY_set1_EC_KEY(EVP_PKEY *pkey, EC_KEY *key);
  int EVP_PKEY_base_id(const EVP_PKEY *pkey);
  int EVP_PKEY_size(const EVP_PKEY *pkey);
  
  EVP_MD_CTX *EVP_MD_CTX_new(void);
  void EVP_MD_CTX_free(EVP_MD_CTX *ctx);
  /*__owur*/ int EVP_DigestInit_ex(EVP_MD_CTX *ctx, const EVP_MD *type,
                                 ENGINE *impl);
  /*__owur*/ int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *d,
                                  size_t cnt);
  /*__owur*/ int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md,
                                  unsigned int *s);
  const EVP_MD *EVP_get_digestbyname(const char *name);
  /*__owur*/ int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *d,
                                size_t cnt);
  /*__owur*/ int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md,
                                unsigned int *s);
  /*__owur*/ int EVP_SignFinal(EVP_MD_CTX *ctx, unsigned char *md, unsigned int *s,
                         EVP_PKEY *pkey);
  /*__owur*/ int EVP_VerifyFinal(EVP_MD_CTX *ctx, const unsigned char *sigbuf,
                           unsigned int siglen, EVP_PKEY *pkey);

  int EVP_PKEY_get_default_digest_nid(EVP_PKEY *pkey, int *pnid);
  const EVP_MD *EVP_get_digestbyname(const char *name);
]]

return {
  EVP_PKEY_RSA = 6,
  EVP_PKEY_DH = 28,
  EVP_PKEY_EC = 408,
}
