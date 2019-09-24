# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;;";
};

run_tests();

__DATA__
=== TEST 1: Generates RSA key by default
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p = openssl.pkey.new()
            ngx.say(p:toPEM('private'))
        }
    }
--- request
    GET /t
--- response_body_like eval
"-----BEGIN PRIVATE KEY-----"
--- no_error_log
[error]

=== TEST 2: Generates RSA key explictly
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p = openssl.pkey.new({
                type = 'RSA',
                bits = 2048,
            })
            ngx.say(p:toPEM('private'))
        }
    }
--- request
    GET /t
--- response_body_like eval
"-----BEGIN PRIVATE KEY-----"
--- no_error_log
[error]

=== TEST 3: Generates EC key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p = openssl.pkey.new({
                type = 'EC',
                curve = 'prime256v1',
            })
            ngx.say(p:toPEM('private'))
        }
    }
--- request
    GET /t
--- response_body_like eval
"-----BEGIN PRIVATE KEY-----"
--- no_error_log
[error]

=== TEST 4: Rejects invalid arg
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p, err = openssl.pkey.new(123)
            ngx.say(err)
            local p, err = openssl.pkey.new('PRIVATE KEY')
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"unexpected type.+
load key failed.+
"
--- no_error_log
[error]

=== TEST 5: Loads PEM format
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p1, err = openssl.pkey.new()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            local p2, err = openssl.pkey.new(p1:toPEM('private'))
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.print(p1:toPEM('private') == p2:toPEM('private'))
        }
    }
--- request
    GET /t
--- response_body eval
"true"
--- no_error_log
[error]

=== TEST 6: Loads DER format
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p1, err = openssl.pkey.new()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            local pem = p1:toPEM('private')
            local der, err = require("ngx.ssl").priv_key_pem_to_der(pem)
            local p2, err = openssl.pkey.new(der)
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.print(p2 and pem == p2:toPEM('private'))
        }
    }
--- request
    GET /t
--- response_body eval
"true"
--- no_error_log
[error]

=== TEST 7: Extracts parameters
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p, err = openssl.pkey.new({
                exp = 65537,
            })
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            local params, er = p:getParameters()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.say(params.d ~= nil)
            ngx.say(params.e ~= nil)
            ngx.say(params.n ~= nil)
            ngx.say(ngx.encode_base64(params.e:toBinary()))
        }
    }
--- request
    GET /t
--- response_body eval
"true
true
true
AQAB
"
--- no_error_log
[error]

=== TEST 8: Sign and verify
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p, err = openssl.pkey.new()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            
            local digest, err = openssl.digest.new("SHA256")
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            err = digest:update("🕶️", "+1s")
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            local s, err = p:sign(digest)
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.say(#s)
            local v, err = p:verify(s, digest)
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body eval
"256
true
"
--- no_error_log
[error]

=== TEST 9: Outputs public key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p, err = openssl.pkey.new()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.say(p:toPEM())
        }
    }
--- request
    GET /t
--- response_body_like eval
"-----BEGIN PUBLIC KEY-----"
--- no_error_log
[error]