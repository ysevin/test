g_table_struct = g_table_struct or {
    user = { "user_id", "user_type", "nickname", "passwd_sha", "user_level"},
    troy = { "troy_id", "troy_type", "troy_nickname" },
    group_chat = { "group_id", "owner_user_id", "group_nickname" },
    group_user = { "user_id", "group_id", "operate_state"},
    group_troy = { "troy_id", "group_id" },
    group_chat_msg = { "group_msg_id", "group_id", "msg_content", "create_user_troy_id", "create_id_type" },
    content_classify = { "cls_id", "cls_name" },
    content_subclassify = { "subcls_id", "cls_id", "subcls_name" },
    content = { "content_id", "cls_id", "subcls_id", "content_title", "content_data" },
    fashion_cls = { "fashion_id", "fashion_name" },
    fashion_content = { "fashion_id", "content_id" },
    recommend_content = { "recommend_id", "content_list", "event_start_sec", "event_finish_sec" },

    persons = { "nationality", "area", "birthday", "gender", "entry", "company", "phone", "fingerprint", "photo", "remark"},
}

-- 字段类型： 数字填1, 字符串填0
g_table_field_type = g_table_field_type or {
    user = { user_id = 1, user_type = 1, nickname = 0, passwd_sha = 0, user_level = 1 },
    troy = { troy_id = 1, troy_type = 1, troy_nickname = 0 },
    group_chat = { group_id = 1, owner_user_id = 1, group_nickname = 0 },
    group_user = { user_id = 1, group_id = 1, operate_state = 1},
    group_troy = { troy_id = 1, group_id = 1 },
    group_chat_msg = { group_msg_id = 1, group_id = 1, msg_content = 0, create_user_troy_id = 1, create_id_type = 1 },
    content_classify = { cls_id = 1, cls_name = 0},
    content_subclassify = { subcls_id = 1, cls_id = 1, subcls_name = 0 },
    content = { content_id = 1, cls_id = 1, subcls_id = 1, content_title = 0, content_data = 0 },
    fashion_cls = { fashion_id = 1, fashion_name = 0 },
    fashion_content = { fashion_id = 1, content_id =1 },
    recommend_content = { recommend_id = 1, content_list = 0, event_start_sec = 1, event_finish_sec = 1 },
    persons = { nationality = 0, area = 0, birthday = 0, gender = 0, entry = 0, company = 0, phone = 1, fingerprint = 2, photo = 2, remark = 0},
}


local mysql = require "resty.mysql"
local cjson = require "cjson"

local mysql_client = { }
mysql_client._VERSION = '1.0'

function mysql_client.query_mysql(self, _sql, _db)
    local query_res, query_err, query_errno, query_state
    local mysql_client, mysql_err = mysql:new()
    if not mysql_client then
        query_err = string.format("[mysql_client] mysql_err:", mysql_err)
        return query_res, query_err, query_errno, query_state
    end
    query_res, query_err, query_errno, query_state = mysql_client:connect({
        host = "127.0.0.1",
        port = 3306,
        database = _db or "troy",
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

function mysql_client.delete_condition(self, _tbl_name, _condition_dict)
    local tbl_struct = g_table_struct[_tbl_name]
    local tbl_field_type = g_table_field_type[_tbl_name]
    self.last_error_ = ""
    if not tbl_struct or not tbl_field_type then
        self.last_error_ = string.format("[delete_condition] not exist %s table", _tbl_name)
        return
    end
    local condition_sql = ""
    local first_value = true
    for field_name, field_value in pairs(_condition_dict) do
        local field_value_type = tbl_field_type[field_name]
        if not field_value_type then
            self.last_error_ = string.format("[delete_condition] %s table not exist %s field", _tbl_name, field_name)
            return
        end
        if not first_value then condition_sql = string.format("%s and", condition_sql) end
        if field_value_type == 1 then
            condition_sql = string.format("%s %s=%d", condition_sql, field_name, field_value)
        elseif field_value_type == 0 then
            condition_sql = string.format("%s %s=%q", condition_sql, field_name, field_value)
		else
            condition_sql = string.format("%s %s=null", condition_sql, field_name)
        end
        first_value = false
    end
    if #condition_sql <= 0 then
        self.last_error_ = string.format("[delete_condition] %s table not exist condition", _tbl_name)
        return
    end
    
    local delete_sql = string.format("delete from %s where %s;", _tbl_name, condition_sql)
    local del_res, del_err, del_errno, del_state = self:query_mysql(delete_sql)
    if not del_res then
        self.last_error_ = string.format("[delete_condition] mysql query err: %s, sql: %s", del_err, delete_sql)
        return
    end
    return del_res.affected_rows
end

function mysql_client.read_condition(self, _tbl_name, _condition_dict)
    local tbl_struct = g_table_struct[_tbl_name]
    local tbl_field_type = g_table_field_type[_tbl_name]
    self.last_error_ = ""
    if not tbl_struct or not tbl_field_type then
        self.last_error_ = string.format("[read_condition] not exist %s table", _tbl_name)
        return
    end
    local condition_sql = ""
    local first_value = true
    for field_name, field_value in pairs(_condition_dict) do
        local field_value_type = tbl_field_type[field_name]
        if not first_value then condition_sql = string.format("%s and ", condition_sql) end
        if field_value_type == 1 then
            condition_sql = string.format("%s %s=%d", condition_sql, field_name, field_value)
        else
            condition_sql = string.format("%s %s=%q", condition_sql, field_name, field_value)
        end
        first_value = false
    end
    local read_sql = string.format("select %s from %s where %s;", table.concat(tbl_struct, ","), _tbl_name, condition_sql)
    local get_res, get_err, get_errno, get_state = self:query_mysql(read_sql)
    if not get_res then
        self.last_error_ = string.format("[read] mysql query err: %s, sql: %s", get_err, read_sql)
        return
    end
    return get_res
end

function mysql_client.read_follow_msg(self, _tbl_name, _follow_name, _follow_value, _equal_name, _equal_value)
    local tbl_struct = g_table_struct[_tbl_name]
    local tbl_field_type = g_table_field_type[_tbl_name]
    self.last_error_ = ""
    if not tbl_struct or not tbl_field_type then
        self.last_error_ = string.format("[read_follow_msg] not exist %s table", _tbl_name)
        return
    end
    local _follow_value_type = tbl_field_type[_follow_name]
    local _equal_value_type = tbl_field_type[_equal_name]
    if not _follow_value_type or not _equal_value_type or _follow_value_type == 0 then
        self.last_error_ = string.format("[read_follow_msg] %s table not exist %s field or %s field, follow_value_type = %d",
                                    _tbl_name, _follow_name, _equal_name, _follow_value_type)
        return
    end
    local condition_sql = ""
    condition_sql = string.format("%s %s>%d and", condition_sql, _follow_name, _follow_value)
    if _equal_value_type == 1 then
        condition_sql = string.format("%s %s=%d", condition_sql, _equal_name, _equal_value)
    else
        condition_sql = string.format("%s %s=%q", condition_sql, _equal_name, _equal_value)
    end
    local read_sql = string.format("select %s from %s where %s order by %s asc;",
                                    table.concat(tbl_struct, ","), _tbl_name, condition_sql, _follow_name)
    local get_res, get_err, get_errno, get_state = self:query_mysql(read_sql)
    if not get_res then
        self.last_error_ = string.format("[read] mysql query err: %s, sql: %s", get_err, read_sql)
        return
    end
    return get_res
end

function mysql_client.read(self, _tbl_name, _primary_key_value)
    local tbl_struct = g_table_struct[_tbl_name]
    local tbl_field_type = g_table_field_type[_tbl_name]
    self.last_error_ = ""
    if not tbl_struct or not tbl_field_type then
        self.last_error_ = string.format("[read] not exist %s table", _tbl_name)
        return
    end
    local primary_key_name = tbl_struct[1]
    local get_res, get_err, get_errno, get_state
    if not get_res or get_res == ngx.null then
        local read_sql = ""
        if tbl_field_type[primary_key_name] == 1 then
            read_sql = string.format("select %s from %s where %s=%d;", table.concat(tbl_struct, ","), _tbl_name, tbl_struct[1], _primary_key_value)
        else
            read_sql = string.format("select %s from %s where %s=%q;", table.concat(tbl_struct, ","), _tbl_name, tbl_struct[1], _primary_key_value)
        end
        get_res, get_err, get_errno, get_state = self:query_mysql(read_sql)
        if not get_res then
            self.last_error_ = string.format("[read] mysql query err: %s, sql: %s", get_err, read_sql)
            return
        end
        if #get_res ~= 1 then get_res = { }
        else get_res = get_res[1] end
    else
        get_res = cjson.decode(get_res)
    end
    return get_res
end

function mysql_client.update(self, _tbl_name, _data_dict)
    local tbl_struct = g_table_struct[_tbl_name]
    local tbl_field_type = g_table_field_type[_tbl_name]
    self.last_error_ = ""
    if not tbl_struct or not tbl_field_type then
        self.last_error_ = string.format("[update] not exist %s table", _tbl_name)
        return
    end
    local update_sql = string.format("update %s set ", _tbl_name)
    local tbl_size = #tbl_struct
    if tbl_size <= 1 then return end
    local first_value = true
    for field_index = 2, tbl_size, 1 do
        local field_name = tbl_struct[field_index]
        local field_value = _data_dict[field_name]
        if field_value then
            if not first_value then update_sql = string.format("%s,", update_sql) end
            if tbl_field_type[field_name] == 1 then
                update_sql = string.format("%s %s=%d", update_sql, field_name, field_value)
            else
                update_sql = string.format("%s %s=%q", update_sql, field_name, field_value)
            end
            first_value = false
        end
    end
    local primary_key_name = tbl_struct[1]
    local primary_key_value = _data_dict[primary_key_name]
    if not primary_key_value then
        self.last_error_ = string.format("[update] %s table don't have %s field value", _tbl_name, primary_key_name)
        return
    end
    if tbl_field_type[primary_key_name] == 1 then
        update_sql = string.format("%s where %s=%d;", update_sql, primary_key_name, primary_key_value)
    else
        update_sql = string.format("%s where %s=%q;", update_sql, primary_key_name, primary_key_value)
    end
    local update_res, update_err, update_errno, update_state = self:query_mysql(update_sql)
    if not update_res or update_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[update] mysql query err: %s, sql: %s, res: %s", update_err, update_sql, cjson.encode(update_res))
        return
    end
    return update_res
end

function mysql_client.update_condition(self, _tbl_name, _data_dict, _condition_dict)
    local tbl_struct = g_table_struct[_tbl_name]
    local tbl_field_type = g_table_field_type[_tbl_name]
    self.last_error_ = ""
    if not tbl_struct or not tbl_field_type then
        self.last_error_ = string.format("[update_condition] not exist %s table", _tbl_name)
        return
    end
    local update_sql = string.format("update %s set ", _tbl_name)
    local tbl_size = #tbl_struct
    if tbl_size <= 1 then return end
    local first_value = true
    for field_index = 2, tbl_size, 1 do
        local field_name = tbl_struct[field_index]
        local field_value = _data_dict[field_name]
        if field_value then
            if not first_value then update_sql = string.format("%s,", update_sql) end
            if tbl_field_type[field_name] == 1 then
                update_sql = string.format("%s %s=%d", update_sql, field_name, field_value)
            else
                update_sql = string.format("%s %s=%q", update_sql, field_name, field_value)
            end
            first_value = false
        end
    end
    local condition_sql = ""
    first_value = true
    for condition_key, condition_value in pairs(_condition_dict) do
        local field_value_type = tbl_field_type[condition_key]
        if not field_value_type then
            self.last_error_ = string.format("[update_condition] %s table not exist %s filed", _tbl_name, _condition_key)
            return
        end
        if not first_value then condition_sql = string.format(" %s and ", condition_sql) end
        if field_value_type == 1 then
            condition_sql = string.format("%s %s=%d", condition_sql, condition_key, condition_value)
        else
            condition_sql = string.format("%s %s=%q", condition_sql, condition_key, condition_value)
        end
        first_value = false
    end
    if #condition_sql <= 0 then
        self.last_error_ = string.format("[update_condition] %s table not exist condition", _tbl_name)
        return
    end
    update_sql = string.format("%s %s;", update_sql, condition_sql)
    local update_res, update_err, update_errno, update_state = self:query_mysql(update_sql)
    if not update_res or update_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[update] mysql query err: %s, sql: %s, res: %s", update_err, update_sql, cjson.encode(update_res))
        return
    end
    return update_res
end


function mysql_client.insert(self, _tbl_name, _data_dict)
    local tbl_struct = g_table_struct[_tbl_name]
    local tbl_field_type = g_table_field_type[_tbl_name]
    self.last_error_ = ""
    if not tbl_struct or not tbl_field_type then
        self.last_error_ = string.format("[insert] not exist %s table", _tbl_name)
        return
    end
    local insert_sql = string.format("insert into %s(%s) value(", _tbl_name, table.concat(tbl_struct, ","))
    local tbl_size = #tbl_struct
    if tbl_size <= 1 then return end
    for field_index, field_name in ipairs(tbl_struct) do
        local field_value = _data_dict[field_name]
        if not field_value then
            self.last_error_ = string.format("[insert] %s not exist %s field value", _tbl_name, field_name)
			return
        end
        if tbl_field_type[field_name] == 1 then --数字
            insert_sql = string.format("%s %d%s", insert_sql, field_value, field_index == tbl_size and ");" or ",")
        else
            insert_sql = string.format("%s %q%s", insert_sql, field_value, field_index == tbl_size and ");" or ",")
        end
    end
    local insert_res, insert_err, insert_errno, insert_state = self:query_mysql(insert_sql)
    if not insert_res or insert_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[insert] mysql query err: %s, sql: %s, res: %s", insert_err, insert_sql, cjson.encode(insert_res))
        return
    end
    return insert_res
end

function mysql_client.insert_not_check(self, _tbl_name, _data_dict, _data_struct)
	local create_sql = string.format("create table if not exists %s (id bigint primary key auto_increment,", _tbl_name)

	local _data_struct = _data_struct or {}
	local str_name, str_value = "", ""
	for field_name, field_value in pairs(_data_dict) do
		create_sql = string.format("%s %s %s,", create_sql, field_name, _data_struct[field_name] or "varchar(255) default ''")
		str_name = string.format("%s%s,", str_name, field_name)
		str_value = string.format("%s%q,", str_value, tostring(field_value))
	end

	create_sql = string.sub(create_sql, 1, -2)
	create_sql = create_sql..");"

	str_name = string.sub(str_name, 1, -2)
	str_value = string.sub(str_value, 1, -2)
	local insert_sql = string.format("insert into %s(%s) value(%s);", _tbl_name, str_name, str_value)

    local insert_res, insert_err, insert_errno, insert_state = self:query_mysql(create_sql, "person")
    if not insert_res or insert_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[create] mysql query err: %s, sql: %s, res: %s", insert_err, insert_sql, cjson.encode(insert_res))
        --return
    end

    local insert_res, insert_err, insert_errno, insert_state = self:query_mysql(insert_sql, "person")
    if not insert_res or insert_res.affected_rows ~= 1 then
        self.last_error_ = string.format("[insert] mysql query err: %s, sql: %s, res: %s", insert_err, insert_sql, cjson.encode(insert_res))
        return
    end
    return insert_res
end

function mysql_client.read_condition_not_check(self, _tbl_name, _condition_dict)
    self.last_error_ = ""
    local condition_sql = ""
    for field_name, field_value in pairs(_condition_dict) do
        condition_sql = string.format("%s %s=%q", condition_sql, field_name, field_value)
    end
    local read_sql = string.format("select * from %s where %s;", _tbl_name, condition_sql)
    local get_res, get_err, get_errno, get_state = self:query_mysql(read_sql, "person")
    if not get_res then
        self.last_error_ = string.format("[read] mysql query err: %s, sql: %s", get_err, read_sql)
        return
    end
    return get_res
end

return mysql_client

