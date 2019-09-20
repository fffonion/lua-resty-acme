local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_cast = ffi.cast

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  typedef struct stack_st OPENSSL_STACK; /* Use STACK_OF(...) instead */
  OPENSSL_STACK *OPENSSL_sk_new_null(void);
  void OPENSSL_sk_free(OPENSSL_STACK *);
]]

local function SKM_sk_new_null(typ)
  local s = C.OPENSSL_sk_new_null()
  local scast = ffi_cast("stack_st_" .. typ, s)
  ffi_gc(s, C.OPENSSL_sk_free)
  return scast
end
