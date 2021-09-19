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
=== TEST 1: Vault authentication failed if no token or jwt provided
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({
                https = true,
                tls_verify = false,
                port = 8210,
                kv_path = "secret/acme",
            })
            local err = st:set("keyssl1", "1")
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"errors from vault: \\[\"missing client token\"\\]
"
--- no_error_log
[error]


=== TEST 2: Vault authenticate using kubernetes
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({
                https = true,
                tls_verify = false,
                auth_method = "kubernetes",
                auth_path = "kubernetes.test",
                jwt_path = "t/fixtures/serviceaccount.jwt",
                auth_role = "root",
                port = 8210,
                kv_path = "secret/acme",
            })
            local err = st:set("keyssl2", "2")
            ngx.say(err)
            local v, err = st:get("keyssl2")
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


=== TEST 3: Vault authenticate using kubernetes (case-insensitivity test)
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({
                https = true,
                tls_verify = false,
                auth_method = "KuBeRnEtEs",
                auth_path = "kubernetes.test",
                jwt_path = "t/fixtures/serviceaccount.jwt",
                auth_role = "root",
                port = 8210,
                kv_path = "secret/acme",
            })
            local err = st:set("keyssl3", "3")
            ngx.say(err)
            local v, err = st:get("keyssl3")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
3
"
--- no_error_log
[error]

