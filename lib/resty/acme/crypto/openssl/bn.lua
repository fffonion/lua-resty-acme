local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_str = ffi.string
local floor = math.floor

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

local BN_ULONG
if true then
  BN_ULONG = 'unsigned long long'
else -- 32bit
  BN_ULONG = 'unsigned int'
end

ffi.cdef(
[[
  struct bignum_st {
    ]] .. BN_ULONG ..[[ *d;     /* Pointer to an array of 'BN_BITS2' bit
                                 * chunks. */
    int top;                    /* Index of last used d +1. */
    /* The next are internal book keeping for bn_expand. */
    int dmax;                   /* Size of the d array. */
    int neg;                    /* one if the number is negative */
    int flags;
};

  BIGNUM *BN_new(void);
  void BN_free(BIGNUM *a);
  int BN_add_word(BIGNUM *a, ]] .. BN_ULONG ..[[ w);
  int BN_set_word(BIGNUM *a, ]] .. BN_ULONG ..[[ w);
  int BN_num_bits(const BIGNUM *a);
  int BN_bn2bin(const BIGNUM *a, unsigned char *to);
]]
-- BN_num_bytes, BN_bn2bin
)

function _M.new(bn)
  local bn = bn or C.BN_new()
  return setmetatable( { bn = bn }, mt)
end

function _M:toBinary()
  local length = (C.BN_num_bits(self.bn)+7)/8
  length = floor(length)
  local buf = ffi_new('unsigned char[?]', length)
  local code = C.BN_bn2bin(self.bn, buf)
  buf = ffi_str(buf, length)
  return buf, nil
end

return _M