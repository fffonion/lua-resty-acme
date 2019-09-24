# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;;";
};

run_tests();

__DATA__
=== TEST 1: Calculate digest correctly
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local digest, err = openssl.digest.new("sha256")
            assert(err == nil)
            digest:update("🦢🦢🦢🦢🦢🦢")
            ngx.print(ngx.encode_base64(digest:final()))
        }
    }
--- request
    GET /t
--- response_body eval
"2iuYqSWdAyVAtQxL/p+AOl2kqp83fN4k+da6ngAt8+s="
--- no_error_log
[error]

=== TEST 2: Update accepts vardiac args
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local digest, err = openssl.digest.new("sha256")
            assert(err == nil)
            digest:update("🦢", "🦢🦢", "🦢🦢", "🦢")
            ngx.print(ngx.encode_base64(digest:final()))
        }
    }
--- request
    GET /t
--- response_body eval
"2iuYqSWdAyVAtQxL/p+AOl2kqp83fN4k+da6ngAt8+s="
--- no_error_log
[error]

=== TEST 3: Final accepts optional arg
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local digest, err = openssl.digest.new("sha256")
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            digest:update("🦢", "🦢🦢", "🦢🦢")
            ngx.print(ngx.encode_base64(digest:final("🦢")))
        }
    }
--- request
    GET /t
--- response_body eval
"2iuYqSWdAyVAtQxL/p+AOl2kqp83fN4k+da6ngAt8+s="
--- no_error_log
[error]

=== TEST 4: Rejects unknown hash
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local digest, err = openssl.digest.new("sha257")
            ngx.print(err)
        }
    }
--- request
    GET /t
--- response_body eval
"EVP_get_digestbyname() failed"
--- no_error_log
[error]