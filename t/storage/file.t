# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
    init_by_lua_block {
        _G.test_lib = require("resty.acme.storage.file")
        _G.test_cfg = nil
        _G.test_ttl = 0.1
    }
};

run_tests();

__DATA__
=== TEST 1: File set key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("key1", "2")
            ngx.say(err)
            local err = st:set("key1", "new value")
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
"
--- no_error_log
[error]

=== TEST 2: File get key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("key2", "3")
            ngx.say(err)
            local v, err = st:get("key2")
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

=== TEST 3: File delete key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("key3", "3")
            ngx.say(err)
            local v, err = st:get("key3")
            ngx.say(err)
            ngx.say(v)
            local err = st:delete("key3")
            ngx.say(err)

            -- now the key should be deleted
            local v, err = st:get("key3")
            ngx.say(err)
            ngx.say(v)

            -- delete again with no error
            local err = st:delete("key3")
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
3
nil
nil
nil
nil
"
--- no_error_log
[error]

=== TEST 4: File list keys NYI
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local keys, err = st:list("prefix")
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nyi
"
--- no_error_log
[error]

=== TEST 5: File set ttl NYI
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("setttl", "bb--", test_ttl)
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nyi
"
--- no_error_log
[error]

=== TEST 6: File add ttl NYI
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:add("addttl", "bb--", test_ttl)
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nyi
"
--- no_error_log
[error]

=== TEST 7: File add only set when key not exist (no ttl support)
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("prefix1", "bb--")
            ngx.say(err)
            local err = st:add("prefix1", "aa--")
            ngx.say(err)
            local v, err = st:get("prefix1")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
exists
nil
bb--
"
--- no_error_log
[error]


