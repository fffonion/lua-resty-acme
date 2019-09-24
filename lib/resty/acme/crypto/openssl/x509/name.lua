local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
require "resty.acme.crypto.openssl.asn1"
require "resty.acme.crypto.openssl.objects"

ffi.cdef [[
  X509_NAME * X509_NAME_new(void);
  void X509_NAME_free(X509_NAME *name);
  int X509_NAME_add_entry_by_OBJ(X509_NAME *name, const ASN1_OBJECT *obj, int type,
                               const unsigned char *bytes, int len, int loc,
                               int set);
]]

local MBSTRING_FLAG = 0x1000
local MBSTRING_ASC  = 0x1001 -- (MBSTRING_FLAG|1)

local _M = {}
local mt = { __index = _M, __tostring = tostring }

function _M.new(cert)
  local ctx = C.X509_NAME_new()
  if ctx == nil then
    return nil, "X509_NAME_new() failed"
  end
  ffi_gc(ctx, C.X509_NAME_free)

  local self = setmetatable({
    ctx = ctx,
  }, mt)

  return self, nil
end


function _M:add(nid, txt)
  local asn1 = C.OBJ_txt2obj(nid, 0)
  if asn1 == nil then
    return "OBJ_txt2obj() failed, invalid NID " .. (nid or "nil")
  end

  local code = C.X509_NAME_add_entry_by_OBJ(self.ctx, asn1, MBSTRING_ASC, txt, #txt, -1, 0)
  C.ASN1_OBJECT_free(asn1)

  if code ~= 1 then
    return "X509_NAME_add_entry_by_OBJ() failed"
  end

end


return _M
