local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_cast = ffi.cast
local ffi_str = ffi.string

local evp_lib = require "resty.acme.crypto.openssl.evp"
require "resty.acme.crypto.openssl.rsa"
local bn_lib = require "resty.acme.crypto.openssl.bn"
require "resty.acme.crypto.openssl.bio"
require "resty.acme.crypto.openssl.pem"

local function generate_key(config)
  local ctx = C.EVP_PKEY_new()

  local type = config.type or 'RSA'
  local bits = config.bits or 2048
  if bits > 4294967295 then
    return nil, "bits out of range"
  end

  local code, failure

  if type == "RSA" then
    local exp = C.BN_new()
    if exp == nil then
      return nil, "BN_new() failed"
    end
    C.BN_set_word(exp, config.exp or 65537)
    local rsa = C.RSA_new()
    if rsa == nil then
      return nil, "RSA_new() failed"
    end
    code = C.RSA_generate_key_ex(rsa, bits, exp, nil)
    if code ~= 1 then
      failure = 'RSA_generate_key_ex'
      goto rsa_pkey_free
    end
    code = C.EVP_PKEY_set1_RSA(ctx, rsa)
    if code ~= 1 then
      failure = 'EVP_PKEY_set1_RSA'
      goto rsa_pkey_free
    end
::rsa_pkey_free::
    C.BN_free(exp)
    C.RSA_free(rsa)
    if code ~= 1 then
      return nil, "error in " .. failure
    end
  elseif type == "EC" then
  else
    return nil, "unknown type " .. (type or "nil")
  end

  return ctx, nil
end

local function load_pkey(txt)
  local bio = C.BIO_new_mem_buf(txt, #txt)
  if not bio then
    return "BIO_new_mem_buf() failed"
  end
  ffi_gc(bio, C.BIO_free)

  -- #define BIO_CTRL_RESET 1
  local code = C.BIO_ctrl(bio, 1, 0, nil)
  if code ~= 1 then
    return nil, "BIO_ctrl() failed"
  end

  ctx = C.PEM_read_bio_PrivateKey(bio, nil, nil, nil)

  if ctx == nil then
    return nil, "PEM_read_bio_PrivateKey() failed"
  end
  return ctx, nil

end

local function tostring(self, priv_or_public, format)
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

  local code = C.PEM_write_bio_PrivateKey(bio, self.ctx, nil, nil, 0, nil, nil)
  if code ~= 1 then
    return nil, "PEM_write_bio_PrivateKey() failed"
  end

  local buf = ffi_new("char *[1]")
 
  -- BIO_get_mem_data; #define BIO_CTRL_INFO 3
  local length = C.BIO_ctrl(bio, 3, 0, buf)

  return ffi.string(buf[0], length)
end

local _M = {}
local mt = { __index = _M, __tostring = tostring }

-- type
-- bits
-- exp
-- curve
function _M.new(s)
  local ctx, err
  s = s or {}
  if type(s) == 'table' then
    ctx, err = generate_key(s)
  elseif type(s) == 'string' then
    ctx, err = load_pkey(s)
  else
    return nil, "type " .. type(s) .. " is not allowed"
  end

  local key_size = C.EVP_PKEY_size(ctx)

  if err then
    return nil, err
  end

  local self = setmetatable({
    ctx = ctx,
    key_size = key_size,
  }, mt)
  ffi_gc(ctx, C.EVP_PKEY_free)

  return self, nil
end

local empty_table = {}
local bnptr_type = ffi.typeof("const BIGNUM *[1]")
local function get_rsa_params(pkey)
  -- {"n", "e", "d", "p", "q", "dmp1", "dmq1", "iqmp"}
  local rsa_st = C.EVP_PKEY_get0_RSA(pkey)
  if not rsa_st then
    return nil, "EVP_PKEY_get0_RSA() failed"
  end
  --rsa_st = ffi_cast("RSA*", rsa_st)
  return setmetatable(empty_table, {
    __index = function(tbl, k)
      if k == 'n' then
        local bnptr = bnptr_type()
        C.RSA_get0_key(rsa_st, bnptr, nil, nil)
        return bn_lib.new(bnptr[0]), nil
      elseif k == 'e' then
        local bnptr = bnptr_type()
        C.RSA_get0_key(rsa_st, nil, bnptr, nil)
        return bn_lib.new(bnptr[0]), nil
      end
    end
  }), nil
end

function _M:getParameters()
  local key_type = C.EVP_PKEY_base_id(self.ctx)
  if key_type == evp_lib.EVP_PKEY_RSA then
    return get_rsa_params(self.ctx)
  elseif key_type == evp_lib.EVP_PKEY_DH then
  elseif key_type == evp_lib.EVP_PKEY_EC then
  end

  return nil, "key type not supported"
end

local uint_ptr = ffi.typeof("unsigned int[1]")

function _M:sign(digest)
  local buf = ffi_new('unsigned char[?]', self.key_size)
  local length = uint_ptr()
  local code = C.EVP_SignFinal(digest.ctx, buf, length, self.ctx)
  return ffi_str(buf, length[0]), nil
end

function _M:verify(signature, digest)
  local code = C.EVP_VerifyFinal(digest.ctx, signature, #signature, self.ctx)
  if code == 0 then
    return false, nil
  elseif code == 1 then
    return true, nil
  end
  return false, "EVP_VerifyFinal() failed"
end

function _M:toPEM(pub_or_priv)
  return tostring(self)
end

return _M