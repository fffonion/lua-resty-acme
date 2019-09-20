package = "lua-resty-acme"
version = "0.1.0-0"
source = {
   url = "git+https://github.com/fffonion/lua-resty-acme.git"
}
description = {
   summary = "Automatic Let's Encrypt certificate serving and Lua implementation of ACME procotol",
   detailed = [[
    Automatic Let's Encrypt certificate serving (RSA + ECC) and Lua implementation of the ACME protocol.
    This library consits of two parts:

    - `resty.acme.autossl`: automatic lifecycle management of Let's Encrypt certificates
    - `resty.acme.client`: Lua implementation of ACME v2 protocol
   ]],
   homepage = "https://github.com/fffonion/lua-resty-acme",
   license = "BSD"
}
build = {
   type = "builtin",
   modules = {
      autossl = "autossl.lua",
      ["challenge.http-01"] = "challenge/http-01.lua",
      client = "client.lua",
      ["crypto.openssl"] = "crypto/openssl.lua",
      ["crypto.openssl.asn1"] = "crypto/openssl/asn1.lua",
      ["crypto.openssl.bio"] = "crypto/openssl/bio.lua",
      ["crypto.openssl.bn"] = "crypto/openssl/bn.lua",
      ["crypto.openssl.digest"] = "crypto/openssl/digest.lua",
      ["crypto.openssl.ec"] = "crypto/openssl/ec.lua",
      ["crypto.openssl.evp"] = "crypto/openssl/evp.lua",
      ["crypto.openssl.objects"] = "crypto/openssl/objects.lua",
      ["crypto.openssl.ossl_typ"] = "crypto/openssl/ossl_typ.lua",
      ["crypto.openssl.pem"] = "crypto/openssl/pem.lua",
      ["crypto.openssl.pkey"] = "crypto/openssl/pkey.lua",
      ["crypto.openssl.rsa"] = "crypto/openssl/rsa.lua",
      ["crypto.openssl.stack"] = "crypto/openssl/stack.lua",
      ["crypto.openssl.util"] = "crypto/openssl/util.lua",
      ["crypto.openssl.x509.altname"] = "crypto/openssl/x509/altname.lua",
      ["crypto.openssl.x509.csr"] = "crypto/openssl/x509/csr.lua",
      ["crypto.openssl.x509.init"] = "crypto/openssl/x509/init.lua",
      ["crypto.openssl.x509.name"] = "crypto/openssl/x509/name.lua",
      ["crypto.openssl.x509v3"] = "crypto/openssl/x509v3.lua",
      ["storage.file"] = "storage/file.lua",
      ["storage.redis"] = "storage/redis.lua",
      ["storage.shm"] = "storage/shm.lua",
      ["storage.vault"] = "storage/vault.lua",
      util = "util.lua"
   }
}

dependencies = {
   "lua-resty-http >= 0.15-0",
   "lua-resty-worker-events >= 1.0.0-1",
   "lua-resty-lrucache >= 0.09-2",
   "luaossl >= 20190731-0",
}
