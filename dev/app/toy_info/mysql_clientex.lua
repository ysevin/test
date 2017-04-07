local mysql = require "resty.mysql"
local cjson = require "cjson"

local mysql_clientex = { }
mysql_clientex._VERSION = '1.0'

function mysql_clientex.query_mysql(self, _sql, _db)
    local query_res, query_err, query_errno, query_state
    local mysql_client, mysql_err = mysql:new()
    if not mysql_client then
        query_err = string.format("[mysql_client] mysql_err:", mysql_err)
        return query_res, query_err, query_errno, query_state
    end
    query_res, query_err, query_errno, query_state = mysql_client:connect({
        host = "127.0.0.1",
        port = 3306,
        database = _db or "toy",
        user = "root",
        password = "root",
        max_packet_size = 1024 * 1024 
    })
    if not query_res then
        query_err = string.format("[mysql_client] connect mysql err: %s, errno: %s, state: %s", query_err, tostring(query_errno), tostring(query_state))
        return query_res, query_err, query_errno, query_state
    end
    mysql_client:set_timeout(5000)
    query_res, query_err, query_errno, query_state = mysql_client:query(_sql)
    mysql_client:set_keepalive(0, 100)
    return query_res, query_err, query_errno, query_state
end

function mysql_clientex.insert(self, _db_name, _tbl_name, _data_dict, _data_struct, _update_key)
	--[[
	local create_db = string.format("create database %s default character set utf8;", _db_name)
    local insert_res, insert_err, insert_errno, insert_state = self:query_mysql(create_db, _db_name)
    if not insert_res or insert_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[create] mysql query err: %s, sql: %s, res: %s", insert_err, insert_sql, cjson.encode(insert_res))
    end
	--]]

	local create_sql = string.format("create table if not exists %s (id bigint primary key auto_increment,", _tbl_name)
	local update_sql = string.format("update %s set ", _tbl_name)

	local _data_struct = _data_struct or {}
	local str_name, str_value = "", ""
	for field_name, field_value in pairs(_data_dict) do
		create_sql = string.format("%s %s %s,", create_sql, field_name, _data_struct[field_name] or "varchar(255) default ''")
		str_name = string.format("%s%s,", str_name, field_name)
		str_value = string.format("%s%q,", str_value, tostring(field_value))
		update_sql = string.format("%s %s=%q,", update_sql, field_name, tostring(field_value))
	end

	create_sql = string.sub(create_sql, 1, -2)
	create_sql = create_sql..");"

	str_name = string.sub(str_name, 1, -2)
	str_value = string.sub(str_value, 1, -2)
	update_sql = string.sub(update_sql, 1, -2)
	local insert_sql = string.format("insert into %s(%s) value(%s);", _tbl_name, str_name, str_value)

	--如果没表, 先创建
    local insert_res, insert_err, insert_errno, insert_state = self:query_mysql(create_sql, _db_name)
    if not insert_res or insert_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[create] mysql query err: %s, sql: %s, res: %s", insert_err, insert_sql, cjson.encode(insert_res))
    end

	--插入新字段
	for field_name, field_value in pairs(_data_dict) do
		local alter_sql = string.format("alter table %s add %s %s;", _tbl_name, field_name, _data_struct[field_name] or "varchar(255) default ''")
    	local insert_res, insert_err, insert_errno, insert_state = self:query_mysql(alter_sql, _db_name)
        self.last_error_ = string.format("[create] mysql query err: %s, sql: %s, res: %s", insert_err, insert_sql, cjson.encode(insert_res))
	end

	--是否是更新数据
	_update_key = _update_key or {}
	update_sql = string.format("%s where", update_sql)
	local is_empty = true
	for field_name, field_value in pairs(_update_key) do
		update_sql = string.format("%s %s=%q", update_sql, field_name, tostring(field_value))
		is_empty = false
	end
	update_sql = update_sql..";"
	local insert_res, insert_err, insert_errno, insert_state
	if not is_empty then
		insert_res, insert_err, insert_errno, insert_state = self:query_mysql(update_sql, _db_name)
	else
    	insert_res, insert_err, insert_errno, insert_state = self:query_mysql(insert_sql, _db_name)
	end

    if not insert_res or insert_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[insert] mysql query err: %s, sql: %s, res: %s", insert_err, update_sql, cjson.encode(insert_res))
		print(self.last_error_)
        return
    end
    return insert_res
end

function mysql_clientex.read_condition(self, _db_name, _tbl_name, _condition_dict)
    self.last_error_ = ""
    local condition_sql = ""
	_condition_dict = _condition_dict or {}
    for field_name, field_value in pairs(_condition_dict) do
        condition_sql = string.format("%s %s=%q", condition_sql, field_name, field_value)
    end
	if condition_sql ~= "" then
		condition_sql = string.format("where %s", condition_sql)
	end
    local read_sql = string.format("select * from %s %s;", _tbl_name, condition_sql)
    local get_res, get_err, get_errno, get_state = self:query_mysql(read_sql, _db_name)
    if not get_res then
        self.last_error_ = string.format("[read] mysql query err: %s, sql: %s", get_err, read_sql)
        return false
    end
    return get_res
end

function mysql_clientex.delete_condition(self, _db_name, _tbl_name, _condition_dict)
    self.last_error_ = ""
    local condition_sql = ""
	_condition_dict = _condition_dict or {}
    for field_name, field_value in pairs(_condition_dict) do
        condition_sql = string.format("%s %s=%q", condition_sql, field_name, field_value)
    end
	if condition_sql ~= "" then
		condition_sql = string.format("where %s", condition_sql)
	end
    local del_sql = string.format("delete from %s %s;", _tbl_name, condition_sql)
    local get_res, get_err, get_errno, get_state = self:query_mysql(del_sql, _db_name)
	ss(get_res)
    if not get_res then
        self.last_error_ = string.format("[read] mysql query err: %s, sql: %s", get_err, del_sql)
		print(self.last_error_)
        return false
    end
    return get_res
end

return mysql_clientex
