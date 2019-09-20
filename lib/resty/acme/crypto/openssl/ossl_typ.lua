local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

ffi.cdef(
[[
  typedef struct rsa_st RSA;
  typedef struct evp_pkey_st EVP_PKEY;
  typedef struct bignum_st BIGNUM;
  typedef struct bn_gencb_st BN_GENCB;
  typedef struct bio_st BIO;
  typedef struct evp_cipher_st EVP_CIPHER;
  typedef struct evp_md_ctx_st EVP_MD_CTX;
  typedef struct engine_st ENGINE;
  typedef struct evp_md_st EVP_MD;
  typedef struct x509_st X509;
  typedef struct X509_name_st X509_NAME;
  typedef struct X509_req_st X509_REQ;
  typedef struct asn1_string_st ASN1_TIME;
  typedef struct asn1_string_st ASN1_STRING;
  typedef struct asn1_object_st ASN1_OBJECT;
]])

