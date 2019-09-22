local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  typedef struct ASN1_VALUE_st ASN1_VALUE;

  typedef struct asn1_type_st {
    int type;
    union {
      char *ptr;
      ASN1_BOOLEAN boolean;
      ASN1_STRING *asn1_string;
      ASN1_OBJECT *object;
      ASN1_INTEGER *integer;
      ASN1_ENUMERATED *enumerated;
      ASN1_BIT_STRING *bit_string;
      ASN1_OCTET_STRING *octet_string;
      ASN1_PRINTABLESTRING *printablestring;
      ASN1_T61STRING *t61string;
      ASN1_IA5STRING *ia5string;
      ASN1_GENERALSTRING *generalstring;
      ASN1_BMPSTRING *bmpstring;
      ASN1_UNIVERSALSTRING *universalstring;
      ASN1_UTCTIME *utctime;
      ASN1_GENERALIZEDTIME *generalizedtime;
      ASN1_VISIBLESTRING *visiblestring;
      ASN1_UTF8STRING *utf8string;
      /*
        * set and sequence are left complete and still contain the set or
        * sequence bytes
        */
      ASN1_STRING *set;
      ASN1_STRING *sequence;
      ASN1_VALUE *asn1_value;
    } value;
  } ASN1_TYPE;

  const unsigned char *ASN1_STRING_get0_data(const ASN1_STRING *x);
  ASN1_OBJECT *ASN1_OBJECT_new(void);
  void ASN1_OBJECT_free(ASN1_OBJECT *a);

  ASN1_STRING *ASN1_STRING_type_new(int type);
  int ASN1_STRING_set(ASN1_STRING *str, const void *data, int len);
]]
