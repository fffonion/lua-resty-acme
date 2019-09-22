--[[
  The OpenSSL stack library. Note `safestack` is not usable here in ffi because
  those symbols are not eaten after preprocessing.
  Instead, we should do a Lua land type checking by having a nested field indicating
  which type of cdata its ctx holds.
]]

local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_cast = ffi.cast

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  typedef struct stack_st OPENSSL_STACK;

  typedef void (*OPENSSL_sk_freefunc)(void *);
  OPENSSL_STACK *OPENSSL_sk_new_null(void);
  int OPENSSL_sk_push(OPENSSL_STACK *st, const void *data);
  void OPENSSL_sk_pop_free(OPENSSL_STACK *st, void (*func) (void *));
  void *OPENSSL_sk_value(const OPENSSL_STACK *, int);
]]

local function gc_of(typ)
  if not typ then
    error("expect a string at #1")
  end
  if not C[typ .. "_free"] then
    error(typ .. "_free is not defined in ffi.cdef")
  end
  local f = C[typ .. "_free"]
  return function (st)
    C.OPENSSL_sk_pop_free(st, f)
  end
end

return {
  gc_of = gc_of
}
