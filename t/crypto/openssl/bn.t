# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;;";
};

run_tests();

__DATA__
=== TEST 1: New BIGNUM instance correctly
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local bn, err = require("resty.acme.crypto.openssl.bn").new()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            local b, err = bn:toBinary()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.print(ngx.encode_base64(b))
        }
    }
--- request
    GET /t
--- response_body eval
""
--- error_log_like
BN_bn2bin faled

=== TEST 2: New BIGNUM instance from number
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local bn, err = require("resty.acme.crypto.openssl.bn").new(0x5b25)
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            local b, err = bn:toBinary()
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.print(ngx.encode_base64(b))
        }
    }
--- request
    GET /t
--- response_body eval
"WyU="
--- no_error_log
[error]