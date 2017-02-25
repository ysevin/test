function init_group_last_msg_id()
    require "global_define"
    local mysql = require "resty.mysql"
    local cjson = require "cjson"
    local mysql_client = require "mysql_client"
    local cache_client = require "cache_client"

    local get_res, get_err, get_errno, get_state = mysql_client:query_mysql("select max(group_msg_id) as group_msg_id, group_id from group_chat_msg group by group_id;")
    if not get_res then
        ngx.log(ngx.ERR, "[app_init] get_err = %s", get_err)
        return
    end
    for _, chat_msg in pairs(get_res) do
        cache_client:hset(GROUP_MSGID_KEY, tonumber(chat_msg.group_id), tonumber(chat_msg.group_msg_id))
    end
end

local ok, err = ngx.timer.at(1, init_group_last_msg_id, nil)
if not ok then ngx.log(ngx.ERR, string.format("init group_last_msg_id failed error = %s", err)) end

