local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new
local ffi_cast = ffi.cast
local ffi_str = ffi.string

require "resty.acme.crypto.openssl.bio"

local function read_using_bio(f, ...)
  if not C[f] then
    return nil, "C." .. f .. "not defined"
  end

  local bio_method = C.BIO_s_mem()
  if bio_method == nil then
      return nil, "BIO_s_mem() failed"
  end
  local bio = C.BIO_new(bio_method)
  ffi_gc(bio, C.BIO_free)
  
  -- BIO_reset; #define BIO_CTRL_RESET 1
  local code = C.BIO_ctrl(bio, 1, 0, nil)
  if code ~= 1 then
      return nil, "BIO_ctrl() failed: " .. code
  end

  local code = C[f](bio, ...)
  if code ~= 1 then
      return nil, f .. "() failed: " .. code
  end
  
  local buf = ffi_new("char *[1]")
  
  -- BIO_get_mem_data; #define BIO_CTRL_INFO 3
  local length = C.BIO_ctrl(bio, 3, 0, buf)
  
  return ffi_str(buf[0], length)
end

return {
  read_using_bio = read_using_bio,
  version_num = version_num,
}