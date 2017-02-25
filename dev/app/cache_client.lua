local redis = require "resty.redis"
local cjson = require "cjson"

local cache_client = { }
cache_client._VERSION = '1.0'

function cache_client.new(self)
    local redis_client, redis_err = redis:new()
    if not redis_client then
        ngx.log(ngx.ERR, "[cache_client] new redis err:", redis_err)
        return
    end
    local redis_res, redis_err = redis_client:connect("127.0.0.1", 6379)
    if not redis_res then
        ngx.log(ngx.ERR, "[db_client] connetc redis err:", redis_err)
        return
    end   
    redis_client:set_timeout(1000)
    return redis_client
end
 
function cache_client.hset(self, _tbl, _key, _value)
    if not _key or not _value then return end
    local redis_client = self:new()
    local redis_ok, redis_err = redis_client:hset(_tbl, _key, _value)
    if not redis_ok then ngx.log(ngx.ERR, string.format("hset failed(%s %s = %s, error = %s)", _tbl, _key, tostring(_value), redis_err)) end
    redis_client:set_keepalive(0, 10)
    return redis_ok
end

function cache_client.hget(self, _tbl, _key)
    if not _key then return end
    local redis_client = self:new()
    local redis_value, redis_err = redis_client:hget(_tbl, _key)
    if not redis_value then ngx.log(ngx.ERR, string.format("hget failed(%s %s, error = %s)", _tbl, _key, redis_err)) end
    redis_client:set_keepalive(0, 10)
    return redis_value
end

function cache_client.hdel(self, _tbl, _key)
    if not _tbl or not _key then return end
    local redis_client = self:new()
    local redis_ok, redis_err = redis_client:hdel(_tbl, _key)
    if not redis_ok then ngx.log(ngx.ERR, string.format("hset failed(%s %s, error = %s)", _tbl, _key, redis_err)) end
    redis_client:set_keepalive(0, 10)
    return redis_ok
end

function cache_client.push(self, _key, _value)
    if not _key or not _value then return end
    local redis_client = self:new()
    local redis_ok, redis_err = redis_client:lpush(_key, _value)
    if not redis_ok then ngx.log(ngx.ERR, string.format("hset failed(%s = %s, error = %s)", _key, tostring(_value), redis_err)) end
    redis_client:set_keepalive(0, 10)
    return redis_ok
end

function cache_client.pop(self, _key)
    if not _key then return end
    local redis_client = self:new()
    local id_lists = { }
    local redis_id, redis_err = redis_client:lpop(_key)
    while redis_id ~= ngx.null and redis_id do
        table.insert(id_lists, redis_id)
        redis_id, redis_err = redis_client:lpop(_key)
    end
    redis_client:set_keepalive(0, 10)
    return id_lists
end

return cache_client
