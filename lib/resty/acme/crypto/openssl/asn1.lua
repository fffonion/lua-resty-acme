local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  const unsigned char *ASN1_STRING_get0_data(const ASN1_STRING *x);
  ASN1_OBJECT *ASN1_OBJECT_new(void);
  void ASN1_OBJECT_free(ASN1_OBJECT *a);
]]
