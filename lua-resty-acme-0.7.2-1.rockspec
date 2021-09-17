package = "lua-resty-acme"
version = "0.7.2-1"
source = {
   url = "git+https://github.com/fffonion/lua-resty-acme.git",
   tag = "0.7.2"
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
      ["resty.acme.challenge.tls-alpn-01"] = "lib/resty/acme/challenge/tls-alpn-01.lua",
      ["resty.acme.client"] = "lib/resty/acme/client.lua",
      ["resty.acme.eab.zerossl-com"] = "lib/resty/acme/eab/zerossl-com.lua",
      ["resty.acme.openssl"] = "lib/resty/acme/openssl.lua",
      ["resty.acme.storage.consul"] = "lib/resty/acme/storage/consul.lua",
      ["resty.acme.storage.etcd"] = "lib/resty/acme/storage/etcd.lua",
      ["resty.acme.storage.file"] = "lib/resty/acme/storage/file.lua",
      ["resty.acme.storage.redis"] = "lib/resty/acme/storage/redis.lua",
      ["resty.acme.storage.shm"] = "lib/resty/acme/storage/shm.lua",
      ["resty.acme.storage.vault"] = "lib/resty/acme/storage/vault.lua",
      ["resty.acme.util"] = "lib/resty/acme/util.lua"
   }
}

dependencies = {
   "lua-resty-http >= 0.15-0",
   "lua-resty-lrucache >= 0.09-2",
   "lua-resty-openssl >= 0.7.0",
   -- "luafilesystem ~> 1",
}
