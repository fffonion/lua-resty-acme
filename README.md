# lua-resty-acme

Automatic Let's Encrypt certificate serving and Lua implementation of the ACME protocol.

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
- luaossl

```shell
luarocks install lua-resty-http
luarocks install luaossl
```

Installing `luaossl` requires you to have a working compiler toolchain and the openssl headers installed
(`libssl-dev` on Ubuntu/Debian, and `openssl-devel` on CentOS/Fedora).

Also, if you are using `resty.acme.autossl`, an extra dependency
[Kong/lua-resty-worker-events](https://github.com/Kong/lua-resty-worker-events) is needed to handle
certificate creation and cache invalidation.

```shell
luarocks install lua-resty-worker-events
```

[Back to TOC](#table-of-contents)

Status
========

Work in progress.

Synopsis
========

Create account private key and fallback certs:

```shell
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out /path/to/account.key
openssl req -newkey rsa:2048 -nodes -keyout /path/to/default.pem -x509 -days 365 -out /path/to/default.key
```

Use the following example config:

```
events {}

http {
    resolver 8.8.8.8;

    lua_shared_dict acme 16m;
    lua_shared_dict autossl_events 128k;

    init_by_lua_block {
        require("resty.acme.autossl").init({
            account_key_path = "/path/to/account.key",
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
        ssl_certificate /path/to/default.pem;
        ssl_certificate_key /path/to/default.key;

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


## resty.acme.autossl

A config table can be passed to `resty.acme.autossl.init()`, the default values are:

```lua
local default_config = {
  -- if using the let's encrypt staging API
  staging = false,
  -- the path to account private key in PEM format
  account_key_path = nil,
  -- the account email to register
  account_email = nil,
  -- the global domain private key
  domain_rsa_key_path = nil,
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
**everytime** Nginx reloads configuration. Note this may trigger
[rate limiting](https://letsencrypt.org/docs/rate-limits/) on Let's Encrypt API.

If `domain_rsa_key_path` is not specified, a new 4096 bits RSA key will be generated
for each certificate. Note that generating such key will block worker and will be
especially noticable on VMs where entropy is low.

See [Storage Adapters](#storage-adapters) section to see

## resty.acme.client

A config table can be passed to `resty.acme.client.new()`, the default values are:

```lua
local default_config = {
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
will not actually create a new account at the ACME server but just return the
previously registered `kid`.

[Back to TOC](#table-of-contents)


## Storage Adapters

Storage adapters are used in `autossl` or acme `client` to storage temporary or
persistent data. Depending on the deployment environment, there're currently
three storage adapters available to select from.

### file

Filesystem based storage. Sample configuration:

```lua
storage_config = {
    dir = '/path/to/storage',
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
- autossl: Persistent the auto generated account key
- autossl: Use cache in autossl
- autossl: Select domain to whitelist/blacklist
- Add tests
- client: Alternatively use lua-resty-nettle when luaossl is not available

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
