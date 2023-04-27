# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
};

run_tests();

__DATA__
=== TEST 1: should fail if namespace is prefixed with any reserved words
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            require("resty.acme.autossl").init({
                tos_accepted = true,
                account_email = "youemail@youdomain.com",
                domain_whitelist = { "example.com" },
                storage_adapter = "redis",
                storage_config = {
                    namespace = ngx.var.uri:sub(4),
                }
            })
        }
    }
--- request
    GET /t/update_lock%3A
--- error_code: 500
--- error_log
namespace can't be prefixed with reserved word: update_lock:
--- request
    GET /t/domain%3Aaaa
--- error_code: 500
--- error_log
namespace can't be prefixed with reserved word: domain:
--- request
    GET /t/account_key%3Abbb
--- error_code: 500
--- error_log
namespace can't be prefixed with reserved word: account_key:
--- request
    GET /t/failure_lock%3Accc
--- error_code: 500
--- error_log
namespace can't be prefixed with reserved word: failure_lock:
--- request
    GET /t/failed_attempts%3Addd
--- error_code: 500
--- error_log
namespace can't be prefixed with reserved word: failed_attempts:


=== TEST 2: should success if namespace is not prefixed with any reserved words
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            require("resty.acme.autossl").init({
                tos_accepted = true,
                account_email = "youemail@youdomain.com",
                domain_whitelist = { "example.com" },
                storage_adapter = "redis",
                storage_config = {
                    namespace = ngx.var.uri:sub(4),
                }
            })
        }
    }
--- request
    GET /t/xxxupdate_lock%3A
--- error_code: 200
--- no_error_log
[error]
--- request
    GET /t/xxxupdate_lock%3Ayyy
--- error_code: 200
--- no_error_log
[error]
--- request
    GET /t/normalname
--- error_code: 200
--- no_error_log
[error]
