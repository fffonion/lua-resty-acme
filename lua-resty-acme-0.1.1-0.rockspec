package = "lua-resty-acme"
version = "0.1.1-0"
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
      ["resty.acme.autossl"] = "lib/resty/acme/autossl.lua",
      ["resty.acme.challenge.http-01"] = "lib/resty/acme/challenge/http-01.lua",
      ["resty.acme.client"] = "lib/resty/acme/client.lua",
      ["resty.acme.crypto.openssl"] = "lib/resty/acme/crypto/openssl.lua",
      ["resty.acme.crypto.openssl.asn1"] = "lib/resty/acme/crypto/openssl/asn1.lua",
      ["resty.acme.crypto.openssl.bio"] = "lib/resty/acme/crypto/openssl/bio.lua",
      ["resty.acme.crypto.openssl.bn"] = "lib/resty/acme/crypto/openssl/bn.lua",
      ["resty.acme.crypto.openssl.digest"] = "lib/resty/acme/crypto/openssl/digest.lua",
      ["resty.acme.crypto.openssl.ec"] = "lib/resty/acme/crypto/openssl/ec.lua",
      ["resty.acme.crypto.openssl.evp"] = "lib/resty/acme/crypto/openssl/evp.lua",
      ["resty.acme.crypto.openssl.objects"] = "lib/resty/acme/crypto/openssl/objects.lua",
      ["resty.acme.crypto.openssl.ossl_typ"] = "lib/resty/acme/crypto/openssl/ossl_typ.lua",
      ["resty.acme.crypto.openssl.pem"] = "lib/resty/acme/crypto/openssl/pem.lua",
      ["resty.acme.crypto.openssl.pkey"] = "lib/resty/acme/crypto/openssl/pkey.lua",
      ["resty.acme.crypto.openssl.rsa"] = "lib/resty/acme/crypto/openssl/rsa.lua",
      ["resty.acme.crypto.openssl.stack"] = "lib/resty/acme/crypto/openssl/stack.lua",
      ["resty.acme.crypto.openssl.util"] = "lib/resty/acme/crypto/openssl/util.lua",
      ["resty.acme.crypto.openssl.x509.altname"] = "lib/resty/acme/crypto/openssl/x509/altname.lua",
      ["resty.acme.crypto.openssl.x509.csr"] = "lib/resty/acme/crypto/openssl/x509/csr.lua",
      ["resty.acme.crypto.openssl.x509.init"] = "lib/resty/acme/crypto/openssl/x509/init.lua",
      ["resty.acme.crypto.openssl.x509.name"] = "lib/resty/acme/crypto/openssl/x509/name.lua",
      ["resty.acme.crypto.openssl.x509v3"] = "lib/resty/acme/crypto/openssl/x509v3.lua",
      ["resty.acme.storage.file"] = "lib/resty/acme/storage/file.lua",
      ["resty.acme.storage.redis"] = "lib/resty/acme/storage/redis.lua",
      ["resty.acme.storage.shm"] = "lib/resty/acme/storage/shm.lua",
      ["resty.acme.storage.vault"] = "lib/resty/acme/storage/vault.lua",
      ["resty.acme.util"] = "lib/resty/acme/util.lua"
   }
}

dependencies = {
   "lua-resty-http >= 0.15-0",
   "lua-resty-worker-events >= 1.0.0-1",
   "lua-resty-lrucache >= 0.09-2",
--   "luaossl >= 20190731-0",
}
