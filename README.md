# lua-resty-acme

Automatic Let's Encrypt certificate serving (RSA + ECC) and pure Lua implementation of the ACMEv2 protocol.

`http-01` and `tls-alpn-01` challenges are supported.

![Build Status](https://travis-ci.com/fffonion/lua-resty-acme.svg?branch=master) ![luarocks](https://img.shields.io/luarocks/v/fffonion/lua-resty-acme?color=%232c3e67)

[简体中文](https://yooooo.us/2019/lua-resty-acme)

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

This library consists of two parts:

- `resty.acme.autossl`: automatic lifecycle management of Let's Encrypt certificates
- `resty.acme.client`: Lua implementation of ACME v2 protocol

Install using opm:

```shell
opm install fffonion/lua-resty-acme
```

Alternatively, to install using luarocks:

```shell
luarocks install lua-resty-acme
```

This library uses [an FFI-based openssl backend](https://github.com/fffonion/lua-resty-openssl),
which currently supports OpenSSL `1.1.1`, `1.1.0` and `1.0.2` series.


[Back to TOC](#table-of-contents)

Status
========

Production.

Synopsis
========

Create account private key and fallback certs:

```shell
# create account key
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out /etc/openresty/account.key
# create fallback cert and key
openssl req -newkey rsa:2048 -nodes -keyout /etc/openresty/default.key -x509 -days 365 -out /etc/openresty/default.pem
```

Use the following example config:

```lua
events {}

http {
    resolver 8.8.8.8 ipv6=off;

    lua_shared_dict acme 16m;

    init_by_lua_block {
        require("resty.acme.autossl").init({
            -- setting the following to true
            -- implies that you read and accepted https://letsencrypt.org/repository/
            tos_accepted = true,
            -- uncomment following for first time setup
            -- staging = true,
            -- uncomment folloing to enable RSA + ECC double cert
            -- domain_key_types = { 'rsa', 'ecc' },
            -- uncomment following to enable tls-alpn-01 challenge
            -- enabled_challenge_handlers = { 'http-01', 'tls-alpn-01' },
            account_key_path = "/etc/openresty/account.key",
            account_email = "youemail@youdomain.com",
            domain_whitelist = { "example.com" },
        })
    }

    init_worker_by_lua_block {
        require("resty.acme.autossl").init_worker()
    }

    server {
        listen 80;
        listen 443 ssl;
        server_name example.com;

        # required to verify Let's Encrypt API
        lua_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
        lua_ssl_verify_depth 2;

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
chain is only supported by NGINX 1.11.0 or later.

A certificate will be *queued* to create after Nginx seen request with such SNI, which might
take tens of seconds to finish. During the meantime, requests with such SNI are responsed
with the fallback certificate.

Note that `domain_whitelist` must be set to include your domain that you wish to server autossl, to
prevent potential abuse using fake SNI in SSL handshake.
```lua
domain_whitelist = { "domain1.com", "domain2.com", "domain3.com" },
```

To match a pattern in your domain name, for  example all subdomains under `example.com`, use:

```lua
domain_whitelist = setmetatable({}, { __index = function(_, k)
    return ngx.re.match(k, [[\.example\.com$]], "jo")
end}),
```

## tls-alpn-01 challenge

<details>
  <summary>Click to expand sample config</summary>

```lua
events {}

http {
    resolver 8.8.8.8 ipv6=off;

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
            -- uncomment following to enable tls-alpn-01 challenge
            -- enabled_challenge_handlers = { 'http-01', 'tls-alpn-01' },
            account_key_path = "/etc/openresty/account.key",
            account_email = "youemail@youdomain.com",
            domain_whitelist = { "example.com" },
            storage_adapter = "file",
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
        listen unix:/tmp/nginx-default.sock ssl;
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

stream {
    lua_shared_dict autossl_events 128k;
    init_worker_by_lua_block {

        require("resty.acme.autossl").init({
            -- setting the following to true
            -- implies that you read and accepted https://letsencrypt.org/repository/
            tos_accepted = true,
            -- uncomment following for first time setup
            -- staging = true,
            -- uncomment folloing to enable RSA + ECC double cert
            -- domain_key_types = { 'rsa', 'ecc' },
            -- uncomment following to enable tls-alpn-01 challenge
            enabled_challenge_handlers = { 'http-01', 'tls-alpn-01' },
            account_key_path = "/etc/openresty/account.key",
            account_email = "youemail@youdomain.com",
            domain_whitelist = { "example.com" },
            storage_adapter = "file"
        })
        require("resty.acme.autossl").init_worker()
    }

    map $ssl_preread_alpn_protocols $backend {
        ~\bacme-tls/1\b unix:/tmp/nginx-tls-alpn.sock;
        default unix:/tmp/nginx-default.sock;
    }

    server {
            listen 443;
            listen [::]:443;

            ssl_preread on;
            proxy_pass $backend;
    }

    server {
            listen unix:/tmp/nginx-tls-alpn.sock ssl;
            ssl_certificate certs/default.pem;
            ssl_certificate_key certs/default.key;

            ssl_certificate_by_lua_block {
                    require("resty.acme.autossl").serve_tls_alpn_challenge()
            }

            content_by_lua_block {
                    ngx.exit(0)
            }
    }
}
```

</details>

In the above sample config, we set a http server and two stream server.

The very front stream server listens for 443 port and route to different upstream
based on client ALPN. The tls-alpn-01 responder listens on `unix:/tmp/nginx-tls-alpn.sock`.
All normal https traffic listens on `unix:/tmp/nginx-default.sock`.

```
                                                [stream server unix:/tmp/nginx-tls-alpn.sock ssl]
                                            Y / 
[stream server 443] --- ALPN is acme-tls ?
                                            N \
                                                [http server unix:/tmp/nginx-default.sock ssl]
```

- The config passed to `require("resty.acme.autossl").init` in both subsystem should be
kept same as possible.
- `tls-alpn-01` challenge handler doesn't need any third party dependency.
- You can enable `http-01` and `tls-alpn-01` challenge handlers at the same time.
- `http` and `stream` subsystem doesn't share shm, thus considering use a storage other
than `shm`. If you must use `shm`, you will need to apply
[this patch](https://github.com/fffonion/lua-resty-shdict-server/tree/master/patches).
- `tls-alpn-01` challenge handler is considered experiemental.

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
  -- restrict registering new cert only with domain defined in this table
  domain_whitelist = nil,
  -- the threshold to renew a cert before it expires, in seconds
  renew_threshold = 7 * 86400,
  -- interval to check cert renewal, in seconds
  renew_check_interval = 6 * 3600,
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

### client.new

**syntax**: *c, err = client.new(config)*

Create a ACMEv2 client.

Default values for `config` are:

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
  -- the challenge types enabled, selection of `http-01` and `tls-alpn-01`
  enabled_challenge_handlers = {"http-01"}
}
```

If `account_kid` is omitted, user must call `client:new_account()` to register a
new account. Note that when using the same `account_key`, `client:new_account()`
will return the same `kid` that is previosuly registered.

See also [Storage Adapters](#storage-adapters) below.

[Back to TOC](#table-of-contents)

### client:init

**syntax**: *err = client:init()*

Initialize the client, requires availability of cosocket API. This function will
login or register an account.

[Back to TOC](#table-of-contents)

### client:order_certificate

**syntax**: *err = client:order_certificate(domain,...)*

Create a certificate with one or more domains. Note that wildcard domains are not
supported as it can only be verified by [dns-01](https://letsencrypt.org/docs/challenge-types/) challenge.

[Back to TOC](#table-of-contents)

### client:serve_http_challenge

**syntax**: *client:serve_http_challenge()*

Serve [http-01](https://letsencrypt.org/docs/challenge-types/) challenge. A common use case will be to
put this as a content_by_* block for `/.well-known` path.

[Back to TOC](#table-of-contents)


## Storage Adapters

Storage adapters are used in `autossl` or acme `client` to storage temporary or
persistent data. Depending on the deployment environment, there're currently
five storage adapters available to select from. To implement a custom storage
adapter, please refer to
[this doc](https://github.com/fffonion/lua-resty-acme/blob/master/lib/resty/acme/storage/README.md).

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
    -- Redis authentication key
    auth = nil,
}
```

Redis >= 2.6.0 is required as this storage requires [PEXPIRE](https://redis.io/commands/pexpire).

### vault

Hashicorp [Vault](https://www.vaultproject.io/) based storage. The default config is:


```lua
storage_config = {
    host = '127.0.0.1',
    port = 8200,
    -- secrets kv prefix path
    kv_path = "acme",
    -- Vault token
    token = nil,
    -- timeout in ms
    timeout = 2000,
}
```

### consul

Hashicorp [Consul](https://www.consul.io/) based storage. The default config is:


```lua
storage_config = {
    host = '127.0.0.1',
    port = 8500,
    -- kv prefix path
    kv_path = "acme",
    -- Consul ACL token
    token = nil,
    -- timeout in ms
    timeout = 2000,
}
```


TODO
====
- autossl: ocsp staping
- openssl: add check for pkey has privkey

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
* [lua-resty-openssl](https://github.com/fffonion/lua-resty-openssl)
* [Let's Encrypt API rate limits](https://letsencrypt.org/docs/rate-limits/)

[Back to TOC](#table-of-contents)
