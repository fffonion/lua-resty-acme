-- https://github.com/GUI/lua-openssl-ffi/blob/master/lib/openssl-ffi/version.lua
local ffi = require "ffi"
local C = ffi.C

ffi.cdef[[
  // 1.0
  unsigned long SSLeay(void);
  // 1.1
  unsigned long OpenSSL_version_num();
]]
local ok, version_num = pcall(function()
  return C.OpenSSL_version_num();
end)

if not ok then
  ok, version_num = pcall(function()
    return C.SSLeay();
  end)
end

return {
    version_num = tonumber(version_num),
    OPENSSL_11 = version_num >= 0x10100000,
    OPENSSL_10 = version_num < 0x10100000,
}