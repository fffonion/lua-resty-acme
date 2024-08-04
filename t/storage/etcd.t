# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "/home/wow/.luarocks/share/lua/5.1/?.lua;/home/wow/.luarocks/share/lua/5.1/?/init.lua;$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
    init_by_lua_block {
        _G.test_lib = require("resty.acme.storage.etcd")
        _G.test_cfg = nil
        _G.test_ttl = 1
    }
};

run_tests();

__DATA__
=== TEST 1: Etcd set key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local key = "key1_" .. ngx.now()
            local err = st:set(key, "2")
            ngx.say(err)
            local err = st:set(key, "new value")
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

=== TEST 2: Etcd get key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local key = "key2_" .. ngx.now()
            local err = st:set(key, "3")
            ngx.say(err)
            local v, err = st:get(key)
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

=== TEST 3: Etcd delete key
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local key = "key3_" .. ngx.now()
            local err = st:set(key, "3")
            ngx.say(err)
            local v, err = st:get(key)
            ngx.say(err)
            ngx.say(v)
            local err = st:delete(key)
            ngx.say(err)

            -- now the key should be deleted
            local v, err = st:get(key)
            ngx.say(err)
            ngx.say(v)

            -- delete again with no error
            local err = st:delete(key)
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

=== TEST 4: Etcd list keys
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local prefix = "prefix4_" .. ngx.now()
            local err = st:set(prefix .. "prefix1", "bb--")
            ngx.say(err)
            local err = st:set("pref-x2", "aa--")
            ngx.say(err)
            local err = st:set(prefix .. "prefix3", "aa--")
            ngx.say(err)

            local keys, err = st:list(prefix)
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
prefix4.+prefix1
prefix4.+prefix3
0
"
--- no_error_log
[error]

=== TEST 5: Etcd set ttl
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local key = "key5_" .. ngx.now()
            local err = st:set(key, "bb--", test_ttl)
            ngx.say(err)
            local v, err = st:get(key)
            ngx.say(err)
            ngx.say(v)
            for i=1, 5 do
                ngx.sleep(1)
                local v, err = st:get(key)
                if err then
                    ngx.say(err)
                    ngx.exit(0)
                elseif not v then
                    ngx.say(nil)
                    ngx.exit(0)
                end
            end
            ngx.say("still exists")
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
bb--
nil
"
--- no_error_log
[error]

=== TEST 6: Etcd add ttl
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local key = "key6_" .. ngx.now()
            local err = st:add(key, "bb--", test_ttl)
            ngx.say(err)
            local v, err = st:get(key)
            ngx.say(err)
            ngx.say(v)
            for i=1, 5 do
                ngx.sleep(1)
                local v, err = st:get(key)
                if err then
                    ngx.say(err)
                    ngx.exit(0)
                elseif not v then
                    ngx.say(nil)
                    ngx.exit(0)
                end
            end
            ngx.say("still exists")
        }
    }
--- request
    GET /t
--- response_body_like eval
"nil
nil
bb--
nil
"
--- no_error_log
[error]

=== TEST 7: Etcd add only set when key not exist
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local st = test_lib.new(test_cfg)
            local key = "key7_" .. ngx.now()
            local err = st:set(key, "bb--", test_ttl)
            ngx.say(err)
            local err = st:add(key, "aa--")
            ngx.say(err)
            local v, err = st:get(key)
            ngx.say(err)
            ngx.say(v)
            -- note: etcd evit expired node not immediately
            for i=1, 5 do
                ngx.sleep(1)
                local v, err = st:get(key)
                if err then
                    ngx.say(err)
                    break
                elseif not v then
                    ngx.say("key evicted")
                    break
                end
            end
            local err = st:add(key, "aa--", test_ttl)
            ngx.say(err)
            local v, err = st:get(key)
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
key evicted
nil
nil
aa--
"
--- no_error_log
[error]


