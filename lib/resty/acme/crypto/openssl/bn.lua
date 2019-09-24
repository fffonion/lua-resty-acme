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
if ffi.abi('64bit') then
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
)

function _M.new(bn)
  local _bn
  if bn == nil or type(bn) == 'number'then
    _bn = C.BN_new()
    ffi_gc(_bn, C.BN_free)
    if type(bn) == 'number' then
      if C.BN_set_word(_bn, bn) ~= 1 then
        C.BN_free(bn)
        return nil, "BN_set_word() failed"
      end
    end
  elseif type(bn) == 'cdata' then
    _bn = bn
  else
    return nil, "unexpected initializer passed in (got " .. type(bn) .. ")"
  end

  return setmetatable( { bn = _bn }, mt), nil
end

function _M:toBinary()
  local length = (C.BN_num_bits(self.bn)+7)/8
  length = floor(length)
  local buf = ffi_new('unsigned char[?]', length)
  local sz = C.BN_bn2bin(self.bn, buf)
  if sz == 0 then
    return nil, "BN_bn2bin() failed"
  end
  buf = ffi_str(buf, length)
  return buf, nil
end

return _M
