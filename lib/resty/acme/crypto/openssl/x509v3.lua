local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_cast = ffi.cast

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  typedef struct GENERAL_NAME_st GENERAL_NAME
]]


