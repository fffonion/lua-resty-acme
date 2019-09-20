local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  ASN1_OBJECT *OBJ_txt2obj(const char *s, int no_name);
  const char *OBJ_nid2sn(int n);
  int OBJ_ln2nid(const char *s);
]]
