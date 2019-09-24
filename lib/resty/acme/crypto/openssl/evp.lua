local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  // >= 1.1
  EVP_PKEY *EVP_PKEY_new(void);
  void EVP_PKEY_free(EVP_PKEY *pkey);
  // 1.0
  EVP_MD_CTX *EVP_MD_CTX_create(void);
  void EVP_MD_CTX_destroy(EVP_MD_CTX *ctx);

  struct rsa_st *EVP_PKEY_get0_RSA(EVP_PKEY *pkey);
  struct ec_key_st *EVP_PKEY_get0_EC_KEY(EVP_PKEY *pkey);
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

  // crypto/internal/evp_int.h
  typedef struct {
    unsigned char pubkey[57];
    unsigned char *privkey;
  } ECX_KEY;
  // typedef /*_Atomic*/ int CRYPTO_REF_COUNT;

    // Note: this struct is trimmed
  struct evp_pkey_st {
    int type;
    int save_type;
    const EVP_PKEY_ASN1_METHOD *ameth;
    ENGINE *engine;
    ENGINE *pmeth_engine;
    union {
        void *ptr;
        struct rsa_st *rsa;
        struct dsa_st *dsa;
        struct dh_st *dh;
        struct ec_key_st *ec;
        ECX_KEY *ecx;
    } pkey;
    // trimmed

    // CRYPTO_REF_COUNT references;
    // CRYPTO_RWLOCK *lock;
    // STACK_OF(X509_ATTRIBUTE) *attributes;
    // int save_parameters;

    // struct {
    //     EVP_KEYMGMT *keymgmt;
    //     void *provkey;
    // } pkeys[10];
    // size_t dirty_cnt_copy;
  };
]]

return {
  EVP_PKEY_RSA = 6,
  EVP_PKEY_DH = 28,
  EVP_PKEY_EC = 408,
}
