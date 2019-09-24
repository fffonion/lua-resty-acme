local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  typedef struct ASN1_VALUE_st ASN1_VALUE;

  typedef struct asn1_type_st ASN1_TYPE;

  ASN1_OBJECT *ASN1_OBJECT_new(void);
  void ASN1_OBJECT_free(ASN1_OBJECT *a);

  ASN1_STRING *ASN1_STRING_type_new(int type);
  int ASN1_STRING_set(ASN1_STRING *str, const void *data, int len);
]]

local OPENSSL_10 = require("resty.acme.crypto.openssl.version").OPENSSL_10

local ASN1_STRING_get0_data
if OPENSSL_10 then
  ffi.cdef[[
    unsigned char *ASN1_STRING_data(ASN1_STRING *x);
  ]]
  ASN1_STRING_get0_data = C.ASN1_STRING_data
else
  ffi.cdef[[
    const unsigned char *ASN1_STRING_get0_data(const ASN1_STRING *x);
  ]]
  ASN1_STRING_get0_data = C.ASN1_STRING_get0_data
end

return {
  ASN1_STRING_get0_data = ASN1_STRING_get0_data
}
  
