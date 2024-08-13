# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
    init_by_lua_block {
        _G.test_lib = require("resty.acme.storage.redis")
        _G.test_cfg = nil
        _G.test_ttl = 0.1
    }
};

run_tests();

__DATA__
=== TEST 1: Redis set key
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

=== TEST 2: Redis get key
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

=== TEST 3: Redis delete key
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

=== TEST 4: Redis list keys
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("prefix1", "bb--")
            ngx.say(err)
            local err = st:set("pref-x2", "aa--")
            ngx.say(err)
            local err = st:set("prefix3", "aa--")
            ngx.say(err)

            local keys, err = st:list("prefix")
            ngx.say(err)
            table.sort(keys)
            for _, p in ipairs(keys) do ngx.say(p) end

            local keys, err = st:list("nonexistent")
            ngx.say(#keys)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
nil
nil
prefix1
prefix3
0
"
--- no_error_log
[error]

=== TEST 5: Redis set ttl
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("setttl", "bb--", test_ttl)
            ngx.say(err)
            local v, err = st:get("setttl")
            ngx.say(err)
            ngx.say(v)
            ngx.sleep(test_ttl)
            local v, err = st:get("setttl")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
bb--
nil
nil
"
--- no_error_log
[error]

=== TEST 6: Redis add ttl
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:add("addttl", "bb--", test_ttl)
            ngx.say(err)
            local v, err = st:get("addttl")
            ngx.say(err)
            ngx.say(v)
            ngx.sleep(test_ttl)
            local v, err = st:get("addttl")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
bb--
nil
nil
"
--- no_error_log
[error]

=== TEST 7: Redis add only set when key not exist
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local err = st:set("prefix1", "bb--", test_ttl)
            ngx.say(err)
            local err = st:add("prefix1", "aa--")
            ngx.say(err)
            local v, err = st:get("prefix1")
            ngx.say(err)
            ngx.say(v)
            ngx.sleep(test_ttl)
            local err = st:add("prefix1", "aa--", test_ttl)
            ngx.say(err)
            local v, err = st:get("prefix1")
            ngx.say(err)
            ngx.say(v)
            ngx.sleep(test_ttl)
            local err = st:add("prefix1", "aa--", test_ttl)
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
exists
nil
bb--
nil
nil
aa--
nil
"
--- no_error_log
[error]

=== TEST 8: Redis namespace set key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({namespace = "foo"})
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

=== TEST 9: Redis namespace get key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({namespace = "foo"})
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

=== TEST 10: Redis namespace delete key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({namespace = "foo"})
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

=== TEST 11: Redis namespace list keys
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({namespace = "foo"})
            local err = st:set("prefix1", "bb--")
            ngx.say(err)
            local err = st:set("pref-x2", "aa--")
            ngx.say(err)
            local err = st:set("prefix3", "aa--")
            ngx.say(err)

            local keys, err = st:list("prefix")
            ngx.say(err)
            table.sort(keys)
            for _, p in ipairs(keys) do ngx.say(p) end

            local keys, err = st:list("nonexistent")
            ngx.say(#keys)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
nil
nil
prefix1
prefix3
0
"
--- no_error_log
[error]

=== TEST 12: Redis namespace add only set when key not exist
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({namespace = "foo"})
            local err = st:set("prefix1", "bb--", test_ttl)
            ngx.say(err)
            local err = st:add("prefix1", "aa--")
            ngx.say(err)
            local v, err = st:get("prefix1")
            ngx.say(err)
            ngx.say(v)
            ngx.sleep(test_ttl)
            local err = st:add("prefix1", "aa--", test_ttl)
            ngx.say(err)
            local v, err = st:get("prefix1")
            ngx.say(err)
            ngx.say(v)
            ngx.sleep(test_ttl)
            local err = st:add("prefix1", "aa--", test_ttl)
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
exists
nil
bb--
nil
nil
aa--
nil
"
--- no_error_log
[error]

=== TEST 13: Redis namespace isolation
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st1 = test_lib.new({namespace = "foo"})
            local st2 = test_lib.new({namespace = "bar"})
            local err = st1:set("isolation", "1")
            ngx.say(err)
            local v, err = st1:get("isolation")
            ngx.say(err)
            ngx.say(v)
            local v, err = st2:get("isolation")
            ngx.say(err)
            ngx.say(v)

            local err = st2:set("isolation", "2")
            ngx.say(err)
            local v, err = st2:get("isolation")
            ngx.say(err)
            ngx.say(v)
            local v, err = st1:get("isolation")
            ngx.say(err)
            ngx.say(v)
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
1
nil
nil
nil
nil
2
nil
1
"
--- no_error_log
[error]

=== TEST 14: Redis list keys with multiple scan calls
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            for i=1,50 do
                local err = st:set(string.format("test14:%02d", i), string.format("value%02d", i))
                ngx.say(err)
            end

            local keys, err = st:list("test14")
            ngx.say(err)
            table.sort(keys)
            for _, p in ipairs(keys) do ngx.say(p) end
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
nil
test14:01
test14:02
test14:03
test14:04
test14:05
test14:06
test14:07
test14:08
test14:09
test14:10
test14:11
test14:12
test14:13
test14:14
test14:15
test14:16
test14:17
test14:18
test14:19
test14:20
test14:21
test14:22
test14:23
test14:24
test14:25
test14:26
test14:27
test14:28
test14:29
test14:30
test14:31
test14:32
test14:33
test14:34
test14:35
test14:36
test14:37
test14:38
test14:39
test14:40
test14:41
test14:42
test14:43
test14:44
test14:45
test14:46
test14:47
test14:48
test14:49
test14:50
"
--- no_error_log
[error]

=== TEST 15: Redis auth works with table
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({auth = { username = "kong", password = "passkong" }, host = "172.27.0.2" })
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

=== TEST 16: Redis auth works with string
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new({auth = "passdefault", host = "172.27.0.2" })
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
