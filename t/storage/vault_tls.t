# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
    init_by_lua_block {
        _G.test_lib = require("resty.acme.storage.vault")
    }
};


run_tests();

__DATA__
=== TEST 1: Vault tls_verify default on
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({
                token = "root",
                port = 8210,
                https = true,
                tls_verify = true,
                kv_path = "secret/acme",
            })
            local err = st:set("keyssl1", "2")
            ngx.say(err)
            local st = test_lib.new({
                token = "root",
                port = 8210,
                https = true,
                kv_path = "secret/acme",
            })
            local v, err = st:get("keyssl1")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"unable to SSL handshake with vault.+
unable to SSL handshake with vault.+
nil
"
--- error_log eval
qr/self.signed certificate/

=== TEST 2: Vault tls_verify off connection ok
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({
                token = "root",
                port = 8210,
                https = true,
                tls_verify = false,
                kv_path = "secret/acme",
            })
            local err = st:set("keyssl1", "2")
            ngx.say(err)
            local v, err = st:get("keyssl1")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
2
"
--- no_error_log
[error]

=== TEST 3: Vault tls_verify with trusted certificate
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        lua_ssl_trusted_certificate /tmp/cert.pem;
        content_by_lua_block {
            local st = test_lib.new({
                token = "root",
                port = 8210,
                https = true,
                kv_path = "secret/acme",
            })
            local err = st:set("keyssl1", "2")
            ngx.say(err)
            local v, err = st:get("keyssl1")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"unable to SSL handshake with vault.+
unable to SSL handshake with vault.+
nil
"
--- error_log
certificate does not match

=== TEST 4: Vault tls_verify with trusted certificate and server_name
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        lua_ssl_trusted_certificate /tmp/cert.pem;
        content_by_lua_block {
            local st = test_lib.new({
                token = "root",
                port = 8210,
                https = true,
                tls_server_name = "some.vault",
                kv_path = "secret/acme",
            })
            local err = st:set("keyssl1", "2")
            ngx.say(err)
            local v, err = st:get("keyssl1")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
2
"
--- no_error_log
[error]

