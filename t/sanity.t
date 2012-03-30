# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?/init.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_MONGO_PORT} ||= 27017;

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: insert use colmt
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(10000) 
            ok, err = conn:connect("10.6.2.51")

            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            col = db:get_col("test")

            col:delete({name="dog"})
            col:insert({{name="dog"}})
            r = col:find({name="dog"})

            for i , v in r:pairs() do
                if v["name"] then
                    ngx.say(v["name"])
                end
            end
            conn:close()
        ';
    }
--- request
GET /t
--- response_body
dog
--- no_error_log
[error]

=== TEST 2: db auth failed
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r,err = db:auth("admin", "pass")
            if not r then ngx.say(err) 
            else
                ngx.say("ok")
            end
        ';
    }
--- request
GET /t
--- response_body
auth fails
--- no_error_log
[error]

=== TEST 3: socket failed
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 
            ok, err = conn:connect("10.6.2.51", 27016)

            if not ok then
                ngx.say("connect failed: "..err)
            end
        ';
    }
--- request
GET /t
--- response_body
connect failed: connection refused
--- error_log
[error]

=== TEST 4: socket reuse
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end
            ngx.say(conn:get_reused_times())

            ok, err = conn:set_keepalive()
            if not ok then
                ngx.say("set keepalive failed: "..err)
            end

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end
            ngx.say(conn:get_reused_times())
        ';
    }
--- request
GET /t
--- response_body
0
1
--- no_error_log
[error]

=== TEST 5: is master
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            r, h = conn:ismaster()
            if not r then
                ngx.say("query master failed: "..h)
            end

            ngx.say(r)
            for i,v in pairs(h) do
                ngx.say(v)
            end
            conn:close()
        ';
    }
--- request
GET /t
--- response_body_like
true
--- no_error_log
[error]

=== TEST 6: is not master
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51", 27018)
            if not ok then
                ngx.say("connect failed: "..err)
            end

            r, h = conn:ismaster()
            if r == nil then
                ngx.say("query master failed: "..h)
            end

            ngx.say(r)
            for i,v in pairs(h) do
                ngx.say(v)
            end
            conn:close()
        ';
    }
--- request
GET /t
--- response_body_like
false
--- no_error_log
[error]

=== TEST 7: get primary
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51", 27018)
            if not ok then
                ngx.say("connect failed: "..err)
            end

            r, h = conn:ismaster()
            if r == nil then
                ngx.say("query master failed: "..h)
            end

            if r then ngx.say("already master") return end

            newconn,err = conn:getprimary()
            if not newconn then
                ngx.say("get primary failed: "..err)
            end
            r, h = newconn:ismaster()
            if not r then
                ngx.say("get master failed")
            end

            ngx.say("get primary")
            conn:close()
        ';
    }
--- request
GET /t
--- response_body
get primary
--- no_error_log
[error]

=== TEST 8: db auth
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r,err = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            ngx.say("ok")
        ';
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]

=== TEST 9: col count
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.OK)
            end
            col = db:get_col("test")

            col:delete({})
            col:insert({{name="sheep"}})
            local n = col:count({name="sheep"})
            ngx.say(n)
        ';
    }
--- request
GET /t
--- response_body
1
--- no_error_log
[error]

=== TEST 10: col update and with $inc
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.OK)
            end

            col = db:get_col("test")
            col:delete({})

            col:insert({{name="dog"}})
            local n = col:update({name="dog"},{name="cat"})
            r = col:find({name="cat"})
            for i , v in r:pairs() do
                if v["name"] then
                    ngx.say(v["name"])
                end
            end

            col:insert({{name="dog",n=1}})
            local update = {}
            update["$inc"] = {n=1}
            local n = col:update({name="dog"},update)
            r = col:find({name="dog"})
            for i , v in r:pairs() do
                if v["n"] then
                    ngx.say(v["n"])
                end
            end
        ';
    }
--- request
GET /t
--- response_body
cat
2
--- no_error_log
[error]

