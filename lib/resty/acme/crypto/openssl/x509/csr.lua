local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
require "resty.acme.crypto.openssl.evp"
require "resty.acme.crypto.openssl.objects"
local stack_lib = require "resty.acme.crypto.openssl.stack"
local util = require "resty.acme.crypto.openssl.util"

ffi.cdef [[
  X509_REQ *X509_REQ_new(void);
  void X509_REQ_free(X509_REQ *req);

  int X509_REQ_set_subject_name(X509_REQ *req, X509_NAME *name);
  int X509_REQ_set_pubkey(X509_REQ *x, EVP_PKEY *pkey);
  int X509_add1_ext_i2d(X509 *x, int nid, void *value, int crit,
                      unsigned long flags);
  int X509_REQ_get_attr_count(const X509_REQ *req);

  int X509_REQ_sign(X509_REQ *x, EVP_PKEY *pkey, const EVP_MD *md);

  int i2d_X509_REQ_bio(BIO *bp, X509_REQ *req);

  // STACK_OF(X509_EXTENSION)
  OPENSSL_STACK *X509_REQ_get_extensions(X509_REQ *req);
  // STACK_OF(X509_EXTENSION)
  int X509_REQ_add_extensions(X509_REQ *req, OPENSSL_STACK *exts);

  typedef struct X509_extension_st X509_EXTENSION;
  X509_EXTENSION *X509_EXTENSION_new(void);
  X509_EXTENSION *X509_EXTENSION_dup(X509_EXTENSION *a);
  void X509_EXTENSION_free(X509_EXTENSION *a);

]]

local function __tostring(self, fmt)
  local method
  if not fmt or fmt == 'PEM' then
    method = 'PEM_write_bio_X509_REQ'
  elseif fmt == 'DER' then
    method = 'i2d_X509_REQ_bio'
  else
    return nil, "can only write PEM or DER format, not " .. fmt
  end
  return util.read_using_bio(method, self.ctx)
end

local _M = {}
local mt = { __index = _M, __tostring = __tostring }

function _M.new()
  local ctx = C.X509_REQ_new()
  if ctx == il then
    return nil, "X509_REQ_new() failed"
  end
  ffi_gc(ctx, C.X509_REQ_free)

  local self = setmetatable({
    ctx = ctx,
  }, mt)

  return self, nil
end


function _M:setSubject(name)
  local code = C.X509_REQ_set_subject_name(self.ctx, name.ctx)
  if code ~= 1 then
    return "X509_REQ_set_subject_name() failed: " .. code
  end
end

local X509_EXTENSION_stack_gc = stack_lib.gc_of("X509_EXTENSION")
local stack_ptr_type = ffi.typeof("struct stack_st *[1]")

-- https://github.com/wahern/luaossl/blob/master/src/openssl.c
local function xr_modifyRequestedExtension(csr, target_nid, value, crit, flags)
  local has_attrs = C.X509_REQ_get_attr_count(csr)
  if has_attrs > 0 then
    return "X509_REQ already has more than more attributes" ..
          "modifying is currently not supported"
  end

  local sk = stack_ptr_type()
  sk[0] = C.X509_REQ_get_extensions(csr)
  ffi_gc(sk[0], X509_EXTENSION_stack_gc)

  local code
  code = C.X509V3_add1_i2d(sk, target_nid, value, crit, flags)
  if code ~= 1 then
    return "X509V3_add1_i2d() failed: " .. code
  end
  code = C.X509_REQ_add_extensions(csr, sk[0])
  if code ~= 1 then
    return "X509_REQ_add_extensions() failed: " .. code
  end

end

function _M:setSubjectAlt(alt)
  -- #define NID_subject_alt_name            85
  -- #define X509V3_ADD_REPLACE              2L
  return xr_modifyRequestedExtension(self.ctx, 85, alt.ctx, 0, 2)
end

function _M:setPublicKey(pkey)
  local code = C.X509_REQ_set_pubkey(self.ctx, pkey.ctx)
  if code ~= 1 then
    return "X509_REQ_set_pubkey() failed: " .. code
  end
end

local int_ptr = ffi.typeof("int[1]")
function _M:sign(pkey)
  local nid = int_ptr()
  local code = C.EVP_PKEY_get_default_digest_nid(pkey.ctx, nid)
  if code <= 0 then -- 1: advisory 2: mandatory
    return "EVP_PKEY_get_default_digest_nid() failed: " .. code
  end
  local name = C.OBJ_nid2sn(nid[0])
  if name == nil then
    return "OBJ_nid2sn() failed"
  end
  local md = C.EVP_get_digestbyname(name)
  if md == nil then
    return "EVP_get_digestbynid() failed"
  end
  local sz = C.X509_REQ_sign(self.ctx, pkey.ctx, md)
  if sz == 0 then
    return "X509_REQ_sign() failed"
  end
end

function _M:tostring(fmt)
  return __tostring(self, fmt)
end

function _M:toPEM()
  return __tostring(self, "PEM")
end


return _M

--[[
  csr:setSubjectAlt(alt)

]]
