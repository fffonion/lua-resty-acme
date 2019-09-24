# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;;";
};


run_tests();

__DATA__
=== TEST 1: Loads a pem cert (FLICKY)
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.update_time()
            local nb_expected = math.floor(ngx.now())
            local na_expected = math.floor(nb_expected + 365 * 86400)
            os.execute("openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out cert.pem -subj '/'")
            local pem = io.open("cert.pem"):read("*a")
            local openssl = require("resty.acme.crypto.openssl")
            local p, err = openssl.x509.new(pem)
            ngx.say(err)
            local not_before, not_after, err = p:getLifetime()
            ngx.say(err)
            ngx.say(not_before == nb_expected or {not_before, "!=", nb_expected})
            ngx.say(not_after == na_expected or {not_after, "!=", na_expected})
            os.remove("key.pem")
            os.remove("cert.pem")
        }
    }
--- request
    GET /t
--- response_body eval
"nil
nil
true
true
"
--- no_error_log
[error]

=== TEST 2: Rejectes invalid cert
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local openssl = require("resty.acme.crypto.openssl")
            local p, err = openssl.x509.new()
            ngx.say(err)
            p, err = openssl.x509.new("222")
            ngx.say(err)
        }
    }
--- request
    GET /t
--- response_body eval
"expect a string at #1
PEM_read_bio_X509() failed
"
--- no_error_log
[error]