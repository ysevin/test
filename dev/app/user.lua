local cjson = require "cjson"
local http = require "resty.http"
local mysql_client = require "mysql_client"
local cache_client = require "cache_client"

local user_handler = { }
user_handler._VERSION = '1.0'

user_handler.socket_state = SOCKET_INIT
user_handler.user_type = 0
user_handler.smsg_code = 0
user_handler.join_group_ids = { }

function user_handler.send_data(_peer_ctx, _data)
    local send_str = cjson.encode(_data)
    local websocket_send_bytes, websocket_send_err = _peer_ctx.websocket_peer_:send_text(send_str)
    if not websocket_send_bytes then ngx.log(ngx.ERR, "send %s failed(%s)", send_str, websocket_send_err) end
end

function user_handler.ack_error(_peer_ctx, _result, _error_str)
    local ack_user_dict = { }
    ack_user_dict.user_result = _result
    ack_user_dict.user_error = _error_str
    user_handler.send_data(_peer_ctx, ack_user_dict)
    return _result == 0 or false
end

function user_handler.update_user_group(_peer_ctx, _user_id, _group_id)
    cache_client:push(_user_id, _group_id)
end

function user_handler.phone_register(_peer_ctx, _msg)
    user_handler.user_type = _msg.user_type
    if user_handler.socket_state == SOCKET_INIT then
        --生成短信验证码
        user_handler.socket_state = SOCKET_CHALLENGE
        user_handler.smsg_code = 123456
        return true, "please input smsg code"
    end
    if user_handler.socket_state ~= SOCKET_CHALLENGE then
        return true, string.format("socket_state = %d error", user_handler.socket_state)
    end
    if type(_msg.user_id) ~= "number" or type(_msg.nickname) ~= "string" or
        type(_msg.smsg_code) ~= "number" or _msg.smsg_code ~= user_handler.smsg_code or
        type(_msg.user_passwd) ~= "string" or #_msg.user_passwd < 6 then
        return false, string.format("user_type = 1, socket_state = %d, user_id = %s, nickname = %s, smsg_code = %d, user_passwd = %s",
                                    user_handler.socket_state, tostring(_msg.user_id), tostring(_msg.nickname), tostring(_msg.smsg_code),
                                    tostring(_msg.user_passwd))
    end
    local insert_data = { }
    insert_data.user_type = _msg.user_type
    insert_data.user_id = _msg.user_id
    insert_data.nickname = _msg.nickname
    insert_data.user_level = 0

    insert_data.passwd_sha = ngx.encode_base64(ngx.hmac_sha1(PASSWD_SECRET_KEY, _msg.user_passwd))
    
    local insert_res = mysql_client:insert("user", insert_data)
    local ack_register_user_dict = { }
    ack_register_user_dict.user_result = -1
    ack_register_user_dict.user_error = mysql_client.last_error_

    if insert_res then
        user_handler.socket_state = SOCKET_INIT
        ack_register_user_dict.user_result = 0
    end
    return insert_res, ack_register_user_dict
end

function user_handler.tx_qq_register(_peer_ctx, _msg)
    local http_client = http.new()
    local http_res, http_err = http_client:request_uri(string.format("https://graph.qq.com/oauth2.0/me?access_token=%s", _msg.code))
    if http_res.status ~= ngx.HTTP_OK then return false end
    local openid_data = json.decode(http_res.body)
    if not openid_data then return false end
    
end

function user_handler.tx_wx_register(_peer_ctx, _msg)
    
end

user_handler.register_callback = { [1] = user_handler.phone_register, [2] =  user_handler.tx_qq_register, [3] = user_handler.tx_wx_register }

function user_handler.user_register(_peer_ctx, _msg)
    if not _msg then return user_handler.ack_error(_peer_ctx, 0, "_msg is nil") end
    if type(_msg.user_type) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_type(%s) is not number", type(_msg.user_type)))
    end
    local register_callback = user_handler.register_callback[_msg.user_type]
    if not register_callback then return user_handler.ack_error(_peer_ctx, 0, string.format("user_type = %d", _msg.user_type)) end
    local register_res, regiser_err = register_callback(_peer_ctx, _msg)

    local ack_register_user_dict = { }
    ack_register_user_dict.user_result = -1
    ack_register_user_dict.user_error = regiser_err
    if register_res then ack_register_user_dict.user_result = 9 end
    
    user_handler.send_data(_peer_ctx, ack_register_user_dict)
    return register_res
end

function user_handler.forgot_passwd(_peer_ctx, _msg)
     if user_handler.socket_state == SOCKET_INIT then
        --生成短信验证码
        user_handler.socket_state = SOCKET_CHALLENGE
        user_handler.smsg_code = 123456
        return true
    end
    if user_handler.socket_state ~= SOCKET_CHALLENGE then
        return user_handler.ack_error(_peer_ctx, 0, string.format("socket_state = %d error", user_handler.socket_state))
    end
    if type(_msg.user_id) ~= "number" or type(_msg.smsg_code) ~= "number" or _msg.smsg_code ~= user_handler.smsg_code or
        type(_msg.new_passwd) ~= "string" or #_msg.new_passwd < 6 then
        return user_handler.ack_error(_peer_ctx, 0,
                                    string.format("socket_state = %d, user_id = %s, smsg_code = %d, new_passwd = %s",
                                        user_handler.socket_state, tostring(_msg.user_id), tostring(_msg.smsg_code), tostring(_msg.new_passwd)))
    end
    local update_user = { user_id = _msg.user_id }
    update_user.passwd_sha = ngx.encode_base64(ngx.hmac_sha1(PASSWD_SECRET_KEY, _msg.new_passwd))
    local update_res = mysql_client:update("user", update_user)
    local ack_update_user_dict = { }
    ack_update_user_dict.user_result = -1
    ack_update_user_dict.user_error = mysql_client.last_error_
    if update_res then
        user_handler.socket_state = SOCKET_INIT
        ack_update_user_dict.user_error = "please new passwd retry login"
        ack_update_user_dict.user_result = 0
    end
    user_handler.send_data(_peer_ctx, ack_update_user_dict)
    return true
end

function user_handler.user_login(_peer_ctx, _msg)
    if user_handler.socket_state ~= SOCKET_INIT then
        return user_handler.ack_error(_peer_ctx, 0, string.format("socket_state = %d error", user_handler.socket_state))
    end
    if type(_msg.user_id) ~= "number" or type(_msg.user_passwd) ~= "string" or #_msg.user_passwd < 6 then
        return user_handler.ack_error(_peer_ctx, 0,
                                    string.format("socket_state = %d, user_id = %s, user_passwd = %s",
                                        user_handler.socket_state, tostring(_msg.user_id), tostring(_msg.user_passwd)))
    end
    local get_res = mysql_client:read("user", _msg.user_id)
    local ack_get_user_dict = { }
    ack_get_user_dict.user_result = -1
    ack_get_user_dict.user_error = mysql_client.last_error_
    if get_res then
        local req_passwd_sha = ngx.encode_base64(ngx.hmac_sha1(PASSWD_SECRET_KEY, _msg.user_passwd))
        if req_passwd_sha ~= get_res.passwd_sha then
             ack_get_user_dict.user_error = "passwd error"
             if not get_res.passwd_sha then ack_get_user_dict.user_error = "not exist user" end
        else
            user_handler.socket_state = SOCKET_LOGIN
            _peer_ctx.user_info_ = get_res
            _peer_ctx.user_info_.user_id = tonumber(_peer_ctx.user_info_.user_id)
            ack_get_user_dict.user_result = 0
            
            get_res = mysql_client:read_condition("group_user", { user_id = _msg.user_id })
            if not get_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
            for _, guser_info in pairs(get_res) do
                user_handler.join_group_ids[guser_info.group_id] = 0
            end
        end
    end
    
    user_handler.send_data(_peer_ctx, ack_get_user_dict)
    return true
end

function user_handler.user_update(_peer_ctx, _msg)
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.user_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("socket_state = %d, user_id = %s", user_handler.socket_state, tostring(_msg.user_id)))
    end
    if _msg.nickname and type(_msg.nickname) ~= "string" then
        return user_handler.ack_error(_peer_ctx, 0,
            string.format("socket_state = %d, user_id = %s, nickname = %s", user_handler.socket_state, tostring(_msg.user_id), tostring(_msg.nickname)))
    end
    if _msg.user_passwd and (type(_msg.user_passwd) ~= "string" or #_msg.user_passwd < 6) then
        return user_handler.ack_error(_peer_ctx, 0,
                            string.format("socket_state = %d, user_id = %s, nickname = %s, user_passwd = %s",
                                user_handler.socket_state, tostring(_msg.user_id), tostring(_msg.nickname), tostring(_msg.user_passwd)))
    end
    local update_user = { user_id = _msg.user_id }
    if _msg.user_passwd then
        update_user.passwd_sha = ngx.encode_base64(ngx.hmac_sha1(PASSWD_SECRET_KEY, _msg.user_passwd))
    end
    if _msg.nickname then
        update_user.nickname = _msg.nickname
    end

    local update_res = mysql_client:update("user", update_user)
    local ack_update_user_dict = { }
    ack_update_user_dict.user_result = -1
    ack_update_user_dict.user_error = mysql_client.last_error_
    if update_res then
        ack_update_user_dict.user_result = 0
    end

    user_handler.send_data(_peer_ctx, ack_update_user_dict)
    return true
end

function user_handler.create_group(_peer_ctx, _msg)
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.group_nickname) ~= "string" then return user_handler.ack_error(_peer_ctx, 0, string.format("group_nickname_type = %s", type(_msg.group_nickname))) end
    local group_info = { group_id = 0, owner_user_id = _peer_ctx.user_info_.user_id, group_nickname = _msg.group_nickname }
    local query_res = mysql_client:read_condition("group_chat", { owner_user_id = group_info.owner_user_id } )
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    if #query_res >= 2 then return user_handler.ack_error(_peer_ctx, 0, string.format("current group num(%d) greate %d max", #query_res, 2)) end
    local insert_res = mysql_client:insert("group_chat", group_info)
    local ack_insert_group_dict = { }
    ack_insert_group_dict.user_result = -1
    ack_insert_group_dict.user_error = mysql_client.last_error_
    if insert_res then
        group_info.group_id = insert_res.insert_id
        ack_insert_group_dict.user_result = 0
        insert_res = mysql_client:insert("group_chat_msg", { group_msg_id = 0, group_id = group_info.group_id,
                                                msg_content = string.format("user_id = %d create group_id = %d", _peer_ctx.user_info_.user_id, group_info.group_id),
                                                create_user_troy_id = _peer_ctx.user_info_.user_id, create_id_type = 0 })
        if insert_res then
            cache_client:hset(GROUP_MSGID_KEY, group_info.group_id, insert_res.insert_id)
            --ngx.shared.group_last_msg_id:set(group_info.group_id, insert_res.insert_id, 0)
        end
        user_handler.update_user_group(_peer_ctx, _peer_ctx.user_info_.user_id, group_info.group_id)
    end
    insert_res = mysql_client:insert("group_user", { user_id = group_info.owner_user_id, group_id = group_info.group_id, operate_state = OFFICIAL_GROUP_MEMBER })
    ack_insert_group_dict.user_error = mysql_client.last_error_
    if not insert_res then
        ack_insert_group_dict.user_result = -1
    end
    user_handler.send_data(_peer_ctx, ack_insert_group_dict)
    return true
end

function user_handler.get_group(_peer_ctx, _msg)
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    local get_res = mysql_client:read_condition("group_chat", { owner_user_id = _peer_ctx.user_info_.user_id })
    local ack_get_group_dict = { }
    ack_get_group_dict.user_result = -1
    ack_get_group_dict.user_error = mysql_client.last_error_
    if get_res then
        ack_get_group_dict.user_result = 0
        ack_get_group_dict.group_info_list = get_res
    end
    user_handler.send_data(_peer_ctx, ack_get_group_dict)
    return true
end

function user_handler.check_task(_peer_ctx, _msg)
    if _msg then return end
    if _peer_ctx.user_info_ then
        local group_ids = cache_client:pop(_peer_ctx.user_info_.user_id)
        local ids_len = group_ids and #group_ids or 0
        for idx = 1, ids_len, 1 do
            user_handler.join_group_ids[tonumber(group_ids[idx])] = 0
        end
    end
    local update_group_ids = { }
    for group_id, group_msg_id in pairs(user_handler.join_group_ids) do
        local last_msg_id = cache_client:hget(GROUP_MSGID_KEY, group_id)
        last_msg_id = last_msg_id and tonumber(last_msg_id)
        if last_msg_id and last_msg_id > group_msg_id then
            local query_res = mysql_client:read_follow_msg("group_chat_msg", "group_msg_id", group_msg_id, "group_id", group_id)
            if not query_res then
                ngx.log(ngx.ERR, string.format("group_msg_id = %d, group_id = %d, error = %s", group_msg_id, group_id, mysql_client.last_error_))
            else 
                if #query_res > 0 then
                    update_group_ids[group_id] = tonumber(query_res[1].group_msg_id)
                    local notify_msg_dict = { }
                    notify_msg_dict.notify_msg = cjson.encode(query_res[1])
                    user_handler.send_data(_peer_ctx, notify_msg_dict)
                end
            end
        end
    end
    for update_group_id, update_group_msg_id in pairs(update_group_ids) do
        user_handler.join_group_ids[update_group_id] = update_group_msg_id
    end
end

return user_handler

