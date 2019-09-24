# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;;";
};

run_tests();

__DATA__
=== TEST 1: Load ffi openssl library
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            assert(require("resty.acme.crypto.openssl"))
        }
    }
--- request
    GET /t
--- error_log
using ffi, OpenSSL version linked: 10
--- no_error_log
[error]