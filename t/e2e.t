# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

env_to_nginx("TEST_TRY_NONCE_INFINITELY=1");

$ENV{'tm'} = time;

sub ::make_http_config{
    my ($key_types, $key_path) = @_;
    return qq{
        lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;$pwd/../lib/?.lua;$pwd/../lib/?/init.lua;;";
        lua_package_cpath "$pwd/luajit/lib/?.so;/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";

        lua_shared_dict acme 16m;

        init_by_lua_block {
            -- patch localhost to resolve to 127.0.0.1 :facepalm:
            -- why resolver in github actions doesn't work?
            local old_tcp = ngx.socket.tcp
            local old_tcp_connect

            -- need to do the extra check here: https://github.com/openresty/lua-nginx-module/issues/860
            local function strip_nils(first, second)
                if second then
                    return first, second
                elseif first then
                    return first
                end
            end

            local function resolve_connect(f, sock, host, port, opts)
                if host == "localhost" then
                    host = "127.0.0.1"
                end

                return f(sock, host, strip_nils(port, opts))
            end

            local function tcp_resolve_connect(sock, host, port, opts)
                return resolve_connect(old_tcp_connect, sock, host, port, opts)
            end

            _G.ngx.socket.tcp = function(...)
                local sock = old_tcp(...)

                if not old_tcp_connect then
                    old_tcp_connect = sock.connect
                end

                sock.connect = tcp_resolve_connect

                return sock
            end

            require("resty.acme.autossl").init({
                tos_accepted = true,
                domain_key_types = { $key_types },
                account_key_path = "$key_path",
                account_email = "travis\@youdomain.com",
                domain_whitelist = setmetatable({}, { __index = function()
                    return true
                end}),
                -- bump up this slightly in test
                challenge_start_delay = 3,
            }, {
                api_uri = "https://localhost:14000/dir",
            })
        }
        init_worker_by_lua_block {
            require("resty.acme.autossl").init_worker()
        }

        lua_ssl_trusted_certificate ../../fixtures/pebble.minica.pem;
    }
};


run_tests();

__DATA__
=== TEST 1: Generates CSR with RSA pkey correctly
--- http_config eval: ::make_http_config("'rsa'", "/tmp/account.key")
--- config
    # for use of travis
    listen 5002;
    listen 5001 ssl;
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
            local opts = {
                merge_stderr = true,
                buffer_size = 256000,
            }
            local out
            for i=0,15,1 do
                local proc = ngx_pipe.spawn({'bash', '-c', "echo q |openssl s_client -host 127.0.0.1 -servername ".. ngx.var.domain .. " -port 5001|openssl x509 -noout -text && sleep 0.1"}, opts)
                local data, err, partial = proc:stdout_read_all()
                if ngx.re.match(data, ngx.var.domain) then
                    local f = io.open("/tmp/test1", "w")
                    f:write(data)
                    f:close()
                    ngx.say(data)
                    break
                end
                ngx.sleep(2)
            end
            ngx.say(out or "timeout")
        }
    }
--- request eval
"GET /t/e2e-test1-$ENV{'tm'}"
--- response_body_like eval
"Pebble Intermediate.+CN\\s*=\\s*e2e-test1.+rsaEncryption"
--- no_error_log
[warn]
[error]

=== TEST 2: Serve RSA + ECC dual certs
--- http_config eval: ::make_http_config("'rsa', 'ecc'", "/tmp/account.key")
--- config
    # for use of travis
    listen 5002;
    listen 5001 ssl;
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
            local opts = {
                merge_stderr = true,
                buffer_size = 256000,
            }
            local out
            for i=0,15,1 do
                local proc = ngx_pipe.spawn({'bash', '-c', "echo q |openssl s_client -host 127.0.0.1 -servername ".. ngx.var.domain .. " -port 5001 -cipher ECDHE-RSA-AES128-GCM-SHA256|openssl x509 -noout -text && sleep 0.1"}, opts)
                local data, err, partial = proc:stdout_read_all()
                if ngx.re.match(data, ngx.var.domain) then
                    local proc2 = ngx_pipe.spawn({'bash', '-c', "echo q |openssl s_client -host 127.0.0.1 -servername ".. ngx.var.domain .. " -port 5001 -cipher ECDHE-ECDSA-AES128-GCM-SHA256|openssl x509 -noout -text && sleep 0.1"}, opts)
                    local data2, err, partial = proc2:stdout_read_all()
                    ngx.log(ngx.INFO, data, data2)
                    local f = io.open("/tmp/test2", "w")
                    f:write(data)
                    f:close()
                    if ngx.re.match(data2, ngx.var.domain) then
                        local f = io.open("/tmp/test3", "w")
                        f:write(data2)
                        f:close()
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
"GET /t/e2e-test2-$ENV{'tm'}"
--- response_body_like eval
"Pebble Intermediate.+CN\\s*=\\s*e2e-test2.+rsaEncryption.+Pebble Intermediate.+CN\\s*=\\s*e2e-test2.+id-ecPublicKey
"
--- no_error_log
[warn]
[error]
--- error_log
set ecc key