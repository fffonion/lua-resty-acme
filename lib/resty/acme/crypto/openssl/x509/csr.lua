local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"
require "resty.acme.crypto.openssl.evp"
require "resty.acme.crypto.openssl.objects"

ffi.cdef [[
  X509_REQ *X509_REQ_new(void);
  void X509_REQ_free(X509_REQ *req);

  int X509_REQ_set_subject_name(X509_REQ *req, X509_NAME *name);
  int X509_REQ_set_pubkey(X509_REQ *x, EVP_PKEY *pkey);
  int X509_REQ_sign(X509_REQ *x, EVP_PKEY *pkey, const EVP_MD *md);

  int i2d_X509_REQ_bio(BIO *bp, X509_REQ *req);
]]
local tostring_method = {
  PEM = 'PEM_write_bio_X509_REQ',
  DER = 'i2d_X509_REQ_bio',
}
local function tostring(self, fmt)
  local bio_method = C.BIO_s_mem()
  if not bio_method then
    return nil, "BIO_s_mem() failed"
  end
  local bio = C.BIO_new(bio_method)
  ffi_gc(bio, C.BIO_free)

  -- BIO_reset; #define BIO_CTRL_RESET 1
  local code = C.BIO_ctrl(bio, 1, 0, nil)
  if code ~= 1 then
    return nil, "BIO_ctrl() failed"
  end

  local code
  local method = tostring_method[fmt or 'PEM']
  if not method then
    return nil, "format " .. fmt .. " not supported"
  end
  local code = C[method](bio, self.ctx)
  if code ~= 1 then
    return nil, method .. " () failed"
  end

  local buf = ffi_new("char *[1]")
 
  -- BIO_get_mem_data; #define BIO_CTRL_INFO 3
  local length = C.BIO_ctrl(bio, 3, 0, buf)

  return ffi.string(buf[0], length)
end

local _M = {}
local mt = { __index = _M, __tostring = tostring }

function _M.new()
  local ctx = C.X509_REQ_new()
  if not ctx then
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
    return "X509_REQ_set_subject_name() failed"
  end
end

function _M:setSubjectAlt(alt)
end

function _M:setPublicKey(pkey)
  local code = C.X509_REQ_set_pubkey(self.ctx, pkey.ctx)
  if code ~= 1 then
    return "X509_REQ_set_pubkey() failed"
  end
end

local int_ptr = ffi.typeof("int[1]")
function _M:sign(pkey)
  local nid = int_ptr()
  local code = C.EVP_PKEY_get_default_digest_nid(pkey.ctx, nid)
  if code ~= 1 then
    return "EVP_PKEY_get_default_digest_nid() failed"
  end
  local name = C.OBJ_nid2sn(nid[0])
  if not name then
    return "OBJ_nid2sn() failed"
  end
  local md = C.EVP_get_digestbyname(name)
  if not md then
    return "EVP_get_digestbynid() failed"
  end
  local code = C.X509_REQ_sign(self.ctx, pkey.ctx, md)
  if code == 0 then
    return "X509_REQ_sign() failed"
  end
end

function _M:tostring(fmt)
  return tostring(self, fmt)
end



return _M

--[[
  csr:setSubjectAlt(alt)

]]
