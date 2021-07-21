# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

sub ::make_http_config{
    my ($key_types, $key_path) = @_;
    return qq{
        lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
        lua_package_cpath "$pwd/luajit/lib/?.so;/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
        resolver 8.8.8.8 ipv6=off;

        lua_shared_dict acme 16m;

        init_by_lua_block {
            require("resty.acme.autossl").init({
                -- setting the following to true
                -- implies that you read and accepted https://letsencrypt.org/repository/
                tos_accepted = true,
                staging = true,
                domain_key_types = { $key_types },
                account_key_path = "$key_path",
                account_email = "travis\@youdomain.com",
                domain_whitelist = setmetatable({}, { __index = function()
                    return true
                end}),
                -- bump up this slightly in test
                challenge_start_delay = 5,
            })
        }
        init_worker_by_lua_block {
            require("resty.acme.autossl").init_worker()
        }

        # required to verify Let's Encrypt API
        lua_ssl_trusted_certificate /tmp/ca-certificates.crt;
        lua_ssl_verify_depth 2;
    }
};


run_tests();

__DATA__
=== TEST 1: Generates CSR with RSA pkey correctly
--- http_config eval: ::make_http_config("'rsa'", "/tmp/account.key")
--- config
    # for use of travis
    listen 61984;
    listen 1985 ssl;
    ssl_certificate /tmp/default.pem;
    ssl_certificate_key /tmp/default.key;

    ssl_certificate_by_lua_block {
        require("resty.acme.autossl").ssl_certificate()
    }

    location /.well-known {
        content_by_lua_block {
            require("resty.acme.autossl").serve_http_challenge()
        }
    }

    location ~ /t/(.+) {
        set $domain $1;
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            ngx.log(ngx.INFO, "subdomain is ", ngx.var.domain)
            local opts = {
                merge_stderr = true,
                buffer_size = 256000,
            }
            local out
            for i=0,15,1 do
                local proc = ngx_pipe.spawn({'bash', '-c', "echo q |openssl s_client -host 127.0.0.1 -servername ".. ngx.var.domain .. " -port 1985|openssl x509 -noout -text && sleep 0.1"}, opts)
                local data, err, partial = proc:stdout_read_all()
                if ngx.re.match(data, ngx.var.domain) then
                    ngx.say(data)
                    break
                end
                ngx.sleep(2)
            end
            ngx.say(out or "timeout")
        }
    }
--- request eval
"GET /t/$ENV{'SUBDOMAIN'}.$ENV{'FRP_SERVER_HOST'}"
--- response_body_like eval
"\\(STAGING\\) Let's Encrypt.+CN\\s*=\\s*$ENV{'SUBDOMAIN'}.$ENV{'FRP_SERVER_HOST'}.+rsaEncryption"
--- no_error_log
[warn]
[error]

=== TEST 2: Serve RSA + ECC dual certs
--- http_config eval: ::make_http_config("'rsa', 'ecc'", "/tmp/account.key")
--- config
    # for use of travis
    listen 61984;
    listen 1985 ssl;
    ssl_certificate /tmp/default.pem;
    ssl_certificate_key /tmp/default.key;
    ssl_certificate /tmp/default-ecc.pem;
    ssl_certificate_key /tmp/default-ecc.key;

    ssl_certificate_by_lua_block {
        require("resty.acme.autossl").ssl_certificate()
    }

    location /.well-known {
        content_by_lua_block {
            require("resty.acme.autossl").serve_http_challenge()
        }
    }

    location ~ /t/(.+) {
        set $domain $1;
        content_by_lua_block {
            local ngx_pipe = require "ngx.pipe"
            ngx.log(ngx.INFO, "subdomain is ", ngx.var.domain)
            local opts = {
                merge_stderr = true,
                buffer_size = 256000,
            }
            local out
            for i=0,15,1 do
                local proc = ngx_pipe.spawn({'bash', '-c', "echo q |openssl s_client -host 127.0.0.1 -servername ".. ngx.var.domain .. " -port 1985 -cipher ECDHE-RSA-AES128-GCM-SHA256|openssl x509 -noout -text && sleep 0.1"}, opts)
                local data, err, partial = proc:stdout_read_all()
                if ngx.re.match(data, ngx.var.domain) then
                    local proc2 = ngx_pipe.spawn({'bash', '-c', "echo q |openssl s_client -host 127.0.0.1 -servername ".. ngx.var.domain .. " -port 1985 -cipher ECDHE-ECDSA-AES128-GCM-SHA256|openssl x509 -noout -text && sleep 0.1"}, opts)
                    local data2, err, partial = proc2:stdout_read_all()
                    ngx.log(ngx.INFO, data, data2)
                    if ngx.re.match(data2, ngx.var.domain) then
                        ngx.say(data)
                        ngx.say(data2)
                        break
                    end
                end
                ngx.sleep(2)
            end
            ngx.say(out or "timeout")
        }
    }
--- request eval
"GET /t/$ENV{'SUBDOMAIN'}.$ENV{'FRP_SERVER_HOST'}"
--- response_body_like eval
"\\(STAGING\\) Let's Encrypt.+CN\\s*=\\s*$ENV{'SUBDOMAIN'}.$ENV{'FRP_SERVER_HOST'}.+rsaEncryption.+\\(STAGING\\) Let's Encrypt.+CN\\s*=\\s*$ENV{'SUBDOMAIN'}.$ENV{'FRP_SERVER_HOST'}.+id-ecPublicKey
"
--- no_error_log
[warn]
[error]
--- error_log
set ecc key