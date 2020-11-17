# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
};


run_tests();

__DATA__
=== TEST 1: Generates CSR with RSA pkey correctly
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local util = require("resty.acme.util")
            local openssl = require("resty.acme.openssl")
            local pkey = openssl.pkey.new()
            local der, err = util.create_csr(pkey, "dns1.com", "dns2.com", "dns3.com")
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.update_time()
            local fname = "ci_" .. math.floor(ngx.now() * 1000)
            local f = io.open(fname, "wb")
            f:write(der)
            f:close()
            ngx.say(io.popen("openssl req -inform der -in " .. fname .. " -noout -text", 'r'):read("*a"))
            os.remove(fname)
        }
    }
--- request
    GET /t
--- response_body_like eval
".+CN\\s*=\\s*dns1.com.+rsaEncryption.+2048 bit.+DNS:dns1.com.+DNS:dns2.com.+DNS:dns3.com"
--- no_error_log
[error]

=== TEST 2: Generates CSR with RSA pkey specific bits correctly
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local util = require("resty.acme.util")
            local openssl = require("resty.acme.openssl")
            local pkey = openssl.pkey.new({
                bits = 4096,
            })
            local der, err = util.create_csr(pkey, "dns1.com", "dns2.com", "dns3.com")
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.update_time()
            local fname = "ci_" .. math.floor(ngx.now() * 1000)
            local f = io.open(fname, "wb")
            f:write(der)
            f:close()
            ngx.say(io.popen("openssl req -inform der -in " .. fname .. " -noout -text", 'r'):read("*a"))
            os.remove(fname)
        }
    }
--- request
    GET /t
--- response_body_like eval
".+CN\\s*=\\s*dns1.com.+rsaEncryption.+4096 bit.+DNS:dns1.com.+DNS:dns2.com.+DNS:dns3.com"
--- no_error_log
[error]

=== TEST 3: Generates CSR with EC pkey correctly
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            local util = require("resty.acme.util")
            local openssl = require("resty.acme.openssl")
            local pkey = openssl.pkey.new({
                type = 'EC',
                curve = 'prime256v1',
            })
            local der, err = util.create_csr(pkey, "dns1.com", "dns2.com", "dns3.com")
            if err then
                ngx.log(ngx.ERR, err)
                return
            end
            ngx.update_time()
            local fname = "ci_" .. math.floor(ngx.now() * 1000)
            local f = io.open(fname, "wb")
            f:write(der)
            f:close()
            -- https://github.com/openssl/openssl/issues/8938
            ngx.say(io.popen("openssl asn1parse -inform der -in " .. fname, 'r'):read("*a"))
            os.remove(fname)
        }
    }
--- request
    GET /t
--- response_body_like eval
"commonName.+dns1.com.+id-ecPublicKey.+prime.+301E8208646E73312E636F6D8208646E73322E636F6D8208646E73332E636F6D"
--- no_error_log
[error]