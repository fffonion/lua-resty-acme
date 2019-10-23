# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
};

run_tests();

__DATA__
=== TEST 1: Redis set key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = require("resty.acme.storage.redis")
            st = st.new()
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
            local st = require("resty.acme.storage.redis")
            st = st.new()
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
            local st = require("resty.acme.storage.redis")
            st = st.new()
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
            local st = require("resty.acme.storage.redis")
            st = st.new()
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
