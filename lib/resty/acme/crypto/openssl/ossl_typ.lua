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
  typedef struct evp_pkey_asn1_method_st EVP_PKEY_ASN1_METHOD;
  typedef struct x509_st X509;
  typedef struct X509_name_st X509_NAME;
  typedef struct X509_req_st X509_REQ;
  typedef struct asn1_string_st ASN1_INTEGER;
  typedef struct asn1_string_st ASN1_ENUMERATED;
  typedef struct asn1_string_st ASN1_BIT_STRING;
  typedef struct asn1_string_st ASN1_OCTET_STRING;
  typedef struct asn1_string_st ASN1_PRINTABLESTRING;
  typedef struct asn1_string_st ASN1_T61STRING;
  typedef struct asn1_string_st ASN1_IA5STRING;
  typedef struct asn1_string_st ASN1_GENERALSTRING;
  typedef struct asn1_string_st ASN1_UNIVERSALSTRING;
  typedef struct asn1_string_st ASN1_BMPSTRING;
  typedef struct asn1_string_st ASN1_UTCTIME;
  typedef struct asn1_string_st ASN1_TIME;
  typedef struct asn1_string_st ASN1_GENERALIZEDTIME;
  typedef struct asn1_string_st ASN1_VISIBLESTRING;
  typedef struct asn1_string_st ASN1_UTF8STRING;
  typedef struct asn1_string_st ASN1_STRING;
  typedef struct asn1_object_st ASN1_OBJECT;
  typedef int ASN1_BOOLEAN;
  typedef int ASN1_NULL;
  typedef struct ec_key_st EC_KEY;
  typedef struct rsa_meth_st RSA_METHOD;
  // typedef struct evp_keymgmt_st EVP_KEYMGMT;
  // typedef struct crypto_ex_data_st CRYPTO_EX_DATA;
  // typedef struct bn_mont_ctx_st BN_MONT_CTX;
  // typedef struct bn_blinding_st BN_BLINDING;
  // crypto.h
  // typedef void CRYPTO_RWLOCK;
]])

