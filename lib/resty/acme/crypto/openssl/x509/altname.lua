local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_cast = ffi.cast

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
require "resty.acme.crypto.openssl.x509v3"
local stack_lib = require "resty.acme.crypto.openssl.stack"
require "resty.acme.crypto.openssl.asn1"


local _M = {}
local mt = { __index = _M, __tostring = tostring }

local GENERAL_NAME_stack_gc = stack_lib.gc_of("GENERAL_NAME")

function _M.new()
  local raw = C.OPENSSL_sk_new_null()
  if raw == nil then
    return nil, "OPENSSL_sk_new_null() failed"
  end
  ffi_gc(raw, GENERAL_NAME_stack_gc)
  local ctx = ffi_cast("GENERAL_NAMES*", raw)

  local self = setmetatable({
    ctx = ctx,
    raw = raw
  }, mt)

  return self, nil
end

local GEN_OTHERNAME = 0
local GEN_EMAIL = 1
local GEN_DNS = 2
local GEN_X400 = 3
local GEN_DIRNAME = 4
local GEN_EDIPARTY = 5
local GEN_URI = 6
local GEN_IPADD = 7
local GEN_RID = 8

local types = {
  RFC822Name = GEN_EMAIL,
  RFC822 = GEN_EMAIL,
  RFC822 = GEN_EMAIL,
  UniformResourceIdentifier = GEN_URI,
  URI = GEN_URI,
  DNSName = GEN_DNS,
  DNS = GEN_DNS,
  IPAddress = GEN_IPADD,
  IP = GEN_IPADD,
  DirName = GEN_DIRNAME,
}

for t, gid in pairs(types) do
  types[t:lower()] = gid
end

function _M:add(typ, value)
  if not typ then
    return "expect a string at #1"
  end
  typ = typ:lower()
  if type(value) ~= 'string' then
    return "except a string at #2"
  end

  local txt = value
  local gen_type = types[typ]
  if not gen_type then
    return "unknown type " .. typ
  end

  -- the stack element stays with stack
  -- we shouldn't add gc handler if it's already been
  -- pushed to stack. instead, rely on the gc handler
  -- of the stack to release all memories
  local gen = C.GENERAL_NAME_new()
  if gen == nil then
    return "GENERAL_NAME_new() failed"
  end

  if gen_id == GEN_DIRNAME then
  elseif gen_id == GEN_IPADD then
  end

  gen.type = gen_type

  -- #define V_ASN1_IA5STRING                22
  local asn1_string = C.ASN1_STRING_type_new(22)
  if asn1_string == nil then
    C.GENERAL_NAME_free(gen)
    return "ASN1_STRING_type_new() failed"
  end

  gen.d.ia5 = asn1_string

  local code = C.ASN1_STRING_set(gen.d.ia5, txt, #txt)
  if code ~= 1 then
    C.GENERAL_NAME_free(gen)
    return "ASN1_STRING_set() failed: " .. code
  end

  C.OPENSSL_sk_push(self.ctx, gen)
  return
end

return _M
