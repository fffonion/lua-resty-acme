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
local OPENSSL_10 = require("resty.acme.crypto.openssl.version").OPENSSL_10

local _M = {}

local sk_pop_free_func
if OPENSSL_10 then
  ffi.cdef [[
    typedef struct stack_st _STACK;
    // i made this up
    typedef struct stack_st OPENSSL_STACK;

    _STACK *sk_new_null(void);
    int sk_push(_STACK *st, void *data);
    void sk_pop_free(_STACK *st, void (*func) (void *));
    // sk_value is direct accessing member # define M_sk_value(sk,n)        ((sk) ? (sk)->data[n] : NULL)
  ]]
  sk_pop_free_func = C.sk_pop_free

  _M.OPENSSL_sk_new_null = C.sk_new_null
  _M.OPENSSL_sk_push = C.sk_push
  _M.OPENSSL_sk_pop_free = C.sk_pop_free
  _M.OPENSSL_sk_value = function(st, n)
    if st == nil then
      return nil
    end
    return st.data[n]
  end
else
  ffi.cdef [[
    typedef struct stack_st OPENSSL_STACK;

    typedef void (*OPENSSL_sk_freefunc)(void *);
    OPENSSL_STACK *OPENSSL_sk_new_null(void);
    int OPENSSL_sk_push(OPENSSL_STACK *st, const void *data);
    void OPENSSL_sk_pop_free(OPENSSL_STACK *st, void (*func) (void *));
    void *OPENSSL_sk_value(const OPENSSL_STACK *, int);
  ]]
  sk_pop_free_func = C.OPENSSL_sk_pop_free

  _M.OPENSSL_sk_new_null = C.OPENSSL_sk_new_null
  _M.OPENSSL_sk_push = C.OPENSSL_sk_push
  _M.OPENSSL_sk_pop_free = C.OPENSSL_sk_pop_free
  _M.OPENSSL_sk_value = C.OPENSSL_sk_value
end

_M.gc_of = function (typ)
  if not typ then
    error("expect a string at #1")
  end
  if not C[typ .. "_free"] then
    error(typ .. "_free is not defined in ffi.cdef")
  end
  local f = C[typ .. "_free"]
  return function (st)
    sk_pop_free_func(st, f)
  end
end


return _M
