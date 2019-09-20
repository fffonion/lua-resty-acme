# lua-resty-acme

Automatic Let's Encrypt certificate serving (RSA + ECC) and Lua implementation of the ACME protocol.

Table of Contents
=================

- [Description](#description)
- [Status](#status)
- [Synopsis](#synopsis)
- [TODO](#todo)
- [Copyright and License](#copyright-and-license)
- [See Also](#see-also)


Description
===========

This library consits of two parts:

- `resty.acme.autossl`: automatic lifecycle management of Let's Encrypt certificates
- `resty.acme.client`: Lua implementation of ACME v2 protocol

Dependencies:
- lua-resty-http

```shell
luarocks install lua-resty-http
```

This library uses an FFI-based openssl backend. The FFI version *might* only work with openssl >= 1.1.
Alternatively you can also use `luaossl`. Installing `luaossl` requires you to have a working compiler
toolchain and the openssl headers installed (`libssl-dev` on Ubuntu/Debian, and `openssl-devel`
on CentOS/Fedora).

Also, if you are using `resty.acme.autossl`, two dependencies
[Kong/lua-resty-worker-events](https://github.com/Kong/lua-resty-worker-events) and
[openresty/lua-resty-lrucache](https://github.com/openresty/lua-resty-lrucache) is needed to handle
certificate creation and cache invalidation.

```shell
luarocks install lua-resty-worker-events
luarocks install lua-resty-lrucache
```

[Back to TOC](#table-of-contents)

Status
========

Experimental.

Synopsis
========

Create account private key and fallback certs:

```shell
# create account key
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out /etc/openresty/account.key
# create fallback cert and key
openssl req -newkey rsa:2048 -nodes -keyout /etc/openresty/default.pem -x509 -days 365 -out /etc/openresty/default.key
```

Use the following example config:

```lua
events {}

http {
    resolver 8.8.8.8;

    lua_shared_dict acme 16m;
    lua_shared_dict autossl_events 128k;

    init_by_lua_block {
        require("resty.acme.autossl").init({
            -- setting the following to true
            -- implies that you read and accepted https://letsencrypt.org/repository/
            tos_accepted = true,
            -- uncomment following for first time setup
            -- staging = true,
            -- uncomment folloing to enable RSA + ECC double cert
            -- domain_key_types = { 'rsa', 'ecc' },
            account_key_path = "/etc/openresty/account.key",
            account_email = "youemail@youdomain.com",
        })
    }
    init_worker_by_lua_block {
        require("resty.acme.autossl").init_worker()
    }

    # required to verify Let's Encrypt API
    lua_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
    lua_ssl_verify_depth 2;

    server {
        listen 80;
        listen 443 ssl;
        server_name example.com;

        # fallback certs, make sure to create them before hand
        ssl_certificate /etc/openresty/default.pem;
        ssl_certificate_key /etc/openresty/default.key;

        ssl_certificate_by_lua_block {
            require("resty.acme.autossl").ssl_certificate()
        }

        location /.well-known {
            content_by_lua_block {
                require("resty.acme.autossl").serve_http_challenge()
            }
        }
    }
}
```

When testing deployment, it's recommanded to uncomment the `staging = true` to allow an
end-to-end test of your environment. This can avoid configuration failure result into too
many requests that hits [rate limiting](https://letsencrypt.org/docs/rate-limits/) on Let's Encrypt API.

By default `autossl` only creates RSA certificates. To use ECC certificates or both, uncomment
`domain_key_types = { 'rsa', 'ecc' }`. Note that multiple certificate
chain is only supported by OpenSSL 1.1 and later, check the OpenSSL version your OpenResty
installation is using by runing `openresty -V` first.

A certificate will be *queued* to create after Nginx seen request with such SNI, which might
take tens of seconds to finish. During the meatime, requests with such SNI are responsed
with the fallback certificate.


## resty.acme.autossl

A config table can be passed to `resty.acme.autossl.init()`, the default values are:

```lua
default_config = {
  -- accept term of service https://letsencrypt.org/repository/
  tos_accepted = false,
  -- if using the let's encrypt staging API
  staging = false,
  -- the path to account private key in PEM format
  account_key_path = nil,
  -- the account email to register
  account_email = nil,
  -- number of certificate cache, per type
  cache_size = 100,
  domain_key_paths = {
    -- the global domain RSA private key
    rsa = nil,
    -- the global domain ECC private key
    ecc = nil,
  },
  -- the private key algorithm to use, can be one or both of
  -- 'rsa' and 'ecc'
  domain_key_types = { 'rsa' },
  -- the threshold to renew a cert before it expires, in seconds
  renew_threshold = 7 * 86400,
  -- interval to check cert renewal, in seconds
  renew_check_interval = 6 * 3600,
  -- the shm name to store worker events
  ev_shm = 'autossl_events',
  -- the store certificates
  storage_adapter = "shm",
  -- the storage config passed to storage adapter
  storage_config = {
    shm_name = 'acme',
  },
}
```

If `account_key_path` is not specified, a new account key will be created
**everytime** Nginx reloads configuration. Note this may trigger **New Account**
[rate limiting](https://letsencrypt.org/docs/rate-limits/) on Let's Encrypt API.

If `domain_key_paths` is not specified, a new private key will be generated
for each certificate (4096-bits RSA and 256-bits prime256v1 ECC). Note that
generating such key will block worker and will be especially noticable on VMs
where entropy is low.

See also [Storage Adapters](#storage-adapters) below.

## resty.acme.client

A config table can be passed to `resty.acme.client.new()`, the default values are:

```lua
default_config = {
  -- the ACME v2 API endpoint to use
  api_uri = "https://acme-v02.api.letsencrypt.org",
  -- the account email to register
  account_email = nil,
  -- the account key in PEM format text
  account_key = nil,
  -- the account kid (as an URL)
  account_kid = nil,
  -- storage for challenge and IPC (TODO)
  storage_adapter = "shm",
  -- the storage config passed to storage adapter
  storage_config = {
    shm_name = "acme"
  },
  -- the challenge types enabled
  enabled_challenge_handlers = {"http-01"}
}
```

If `account_kid` is omitted, user must call `client:new_account()` to register a
new account. Note that when using the same `account_key`, `client:new_account()`
will return the same `kid` that is previosuly registered.

See also [Storage Adapters](#storage-adapters) below.

[Back to TOC](#table-of-contents)


## Storage Adapters

Storage adapters are used in `autossl` or acme `client` to storage temporary or
persistent data. Depending on the deployment environment, there're currently
three storage adapters available to select from.

### file

Filesystem based storage. Sample configuration:

```lua
storage_config = {
    dir = '/etc/openresty/storage',
}
```
If `dir` is omitted, the OS temporary directory will be used.

### shm

Lua shared dict based storage. Note this storage is volatile between Nginx restarts
(not reloads). Sample configuration:

```lua
storage_config = {
    shm_name = 'dict_name',
}
```

### redis

Redis based storage. The default config is:

```lua
storage_config = {
    host = '127.0.0.1',
    port = 6379,
    database = 0,
}
```

### vault

Hashicorp [Vault](https://www.vaultproject.io/) based storage.


TODO
====
- autossl: Select domain to register with whitelist/blacklist
- Add tests
- openssl: add check for pkey has privkey
- openssl: add check for self.ctx classmethod call
- openssl: altname/safestack

[Back to TOC](#table-of-contents)


Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2019, by fffonion <fffonion@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)

See Also
========
* [Automatic Certificate Management Environment (ACME)](https://tools.ietf.org/html/rfc8555)
* [haproxytech/haproxy-lua-acme](https://github.com/haproxytech/haproxy-lua-acme) The ACME Lua implementation used in HAProxy.
* [GUI/lua-resty-auto-ssl](https://github.com/GUI/lua-resty-auto-ssl)
* [Let's Encrypt API rate limits](https://letsencrypt.org/docs/rate-limits/)

[Back to TOC](#table-of-contents)
