local cjson = require "cjson"
local mysql_client = require "mysql_client"
local cache_client = require "cache_client"
local group_handler = { }
group_handler._VERSION = '1.0'

function group_handler.add_user_msg(_peer_ctx, _group_id, _msg_content)
    local user_handler = _peer_ctx.user_handler_
    local user_info = _peer_ctx.user_info_
    local insert_res = mysql_client:insert("group_chat_msg", { group_msg_id = 0, group_id = _group_id,
                                                            msg_content = _msg_content,  create_user_troy_id = user_info.user_id, create_id_type = 0 })
    if not insert_res then
        user_handler.ack_error(_peer_ctx, 0, string.format("add_user_msg failed %s", mysql_client.last_error_))
        return
    end
    cache_client:hset(GROUP_MSGID_KEY, _group_id, insert_res.insert_id)
end

function group_handler.invite_troy(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.invite_code) ~= "number" or type(_msg.group_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invite_code_type = %s, group_id = %s", type(_msg.invite_code), type(_msg.group_id)))
    end
    local troy_id, flags = ngx.shared.troy_invite_code:get(_msg.invite_code)
    if not troy_id then return user_handler.ack_error(_peer_ctx, 0, string.format("invite_code = %d not exit troy", _msg.invite_code)) end
    ngx.shared.troy_invite_code:delete(_msg.invite_code)
    
    local query_res = mysql_client:read_condition("group_chat", { group_id = _msg.group_id })
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    if #query_res ~= 1 then return user_handler.ack_error(_peer_ctx, 0, string.format("current group(%d) num(%d)", _msg.group_id, #query_res)) end

    local delete_num = mysql_client:delete_condition("group_troy", { troy_id = troy_id })
    if not delete_num then return user_handler.ack_error(_peer_ctx, 0, string.format("group_id = %d, error = %s", _msg.group_id, mysql_client.last_error_)) end
    
    local insert_res = mysql_client:insert("group_troy", { troy_id = troy_id, group_id = _msg.group_id })
    local ack_invite_troy_dict = { }
    ack_invite_troy_dict.group_result = -1
    ack_invite_troy_dict.group_error = mysql_client.last_error_
    if insert_res then
        ack_invite_troy_dict.group_result = 0
        cache_client:hset(TROY_GROUPID_HKEY, troy_id, _msg.group_id)
    end
    group_handler.add_user_msg(_peer_ctx, _msg.group_id,
                            string.format("user_id = %d, troy_id = %d join group_id = %d success", user_info.user_id, troy_id, _msg.group_id))
 
    user_handler.send_data(_peer_ctx, ack_invite_troy_dict)
    return true
end

function group_handler.invite_user(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.invite_user_id) ~= "number" or type(_msg.group_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invite_user_id_type = %s, group_id = %s", type(_msg.invite_user_id), type(_msg.group_id)))
    end
    local query_res = mysql_client:read_condition("group_chat", { group_id = _msg.group_id })
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    if #query_res ~= 1 then return user_handler.ack_error(_peer_ctx, 0, string.format("invite group(%d) num(%d)", _msg.group_id, #query_res)) end
    local group_info = query_res[1]
    group_info.owner_user_id = tonumber(group_info.owner_user_id)
    if group_info.owner_user_id ~= user_info.user_id then
        return user_handler.ack_error(_peer_ctx, 0, string.format("group_owner_user_id = %d, current_user_id = %d", group_info.owner_user_id, user_info.user_id))
    end

    query_res = mysql_client:read_condition("user", { user_id = _msg.invite_user_id } )
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    if #query_res ~= 1 then return user_handler.ack_error(_peer_ctx, 0, string.format("invite user(%d) num(%d)", _msg.invite_user_id, #query_res)) end
    
    query_res = mysql_client:read_condition("group_user", { user_id = _msg.invite_user_id, group_id = _msg.group_id })
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local need_invite = true
    if #query_res > 0 then need_invite = false end

    local ack_invite_user_dict = {}
    ack_invite_user_dict.invite_user_result = -1
    ack_invite_user_dict.invite_user_error = "already invited"

    if need_invite then
        local insert_res = mysql_client:insert("group_user", { group_id = _msg.group_id, user_id = _msg.invite_user_id, operate_state = INVITE_JOIN_GROUP })
        if not insert_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
        user_handler.update_user_group(_peer_ctx, _msg.invite_user_id, _msg.group_id)
        group_handler.add_user_msg(_peer_ctx, _msg.group_id,
                                        string.format("invite user_id = %d join group_id = %d ", _msg.invite_user_id, _msg.group_id))
        ack_invite_user_dict.invite_user_result = 0
        ack_invite_user_dict.invite_user_error = ""
    end

    user_handler.send_data(_peer_ctx, ack_invite_user_dict)
    return true
end

function group_handler.apply_join(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.apply_group_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("apply_group_id = %s", type(_msg.apply_group_id)))
    end
    local query_res = mysql_client:read_condition("group_chat", { group_id = _msg.apply_group_id } )
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    if #query_res ~= 1 then return user_handler.ack_error(_peer_ctx, 0, string.format("apply_group_id (%d) num(%d)", _msg.apply_group_id, #query_res)) end
    local group_owner_user_id = tonumber(query_res[1].owner_user_id)

    query_res = mysql_client:read_condition("group_user", { user_id = user_info.user_id, group_id = _msg.apply_group_id })
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local need_apply = true
    if #query_res > 0 then need_apply = false end

    local ack_apply_user_dict = {}
    ack_apply_user_dict.apply_user_result = -1
    ack_apply_user_dict.apply_user_error = "already apply"

    if need_apply then
        local insert_res = mysql_client:insert("group_user", { group_id = _msg.apply_group_id, user_id = user_info.user_id, operate_state = APPLY_JOIN_GROUP })
        if not insert_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
        user_handler.update_user_group(_peer_ctx, user_info.user_id, _msg.apply_group_id)
        group_handler.add_user_msg(_peer_ctx, _msg.apply_group_id,
                                        string.format("user_id = %d apply join group_id = %d ", user_info.user_id, _msg.apply_group_id))
        ack_apply_user_dict.apply_user_result = 0
        ack_apply_user_dict.apply_user_error = ""
    end

    user_handler.send_data(_peer_ctx, ack_apply_user_dict)
    return true
end

function group_handler.approve_join(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.apply_group_id) ~= "number" or type(_msg.apply_user_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("apply_group_id = %s, apply_user_id = %s", type(_msg.apply_group_id), type(_msg.apply_user_id)))
    end
    local query_res = mysql_client:read_condition("group_user", { user_id = _msg.apply_user_id, group_id = _msg.apply_group_id })
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local find_user = nil
    if #query_res > 0 then find_user = query_res[1] end

    if not find_user then return user_handler.ack_error(_peer_ctx, 0, string.format("not exist user_id = %d, group_id = %d", _msg.apply_user_id, _msg.apply_grou_id)) end
    find_user.operate_state = tonumber(find_user.operate_state)
    if find_user.operate_state == APPLY_JOIN_GROUP then -- 本人申请，需要创建者approve 
        query_res = mysql_client:read_condition("group_chat", { group_id = _msg.apply_group_id })
        if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
        if #query_res ~= 1 then return user_handler.ack_error(_peer_ctx, 0, string.format("apply_grou_id = %d, num = %d", _msg.apply_group_id, #query_res)) end
        local owner_user_id = tonumber(query_res[1].owner_user_id)
        if user_info.user_id ~= owner_user_id then
            return user_handler.ack_error(_peer_ctx, 0,
                                        string.format("apply_user_id = %d, current_user_id = %d, owner_user_id = %d",
                                                        _msg.apply_group_id, user_info.user_id, owner_user_id))
        end
    elseif find_user.operate_state == INVITE_JOIN_GROUP then -- 被别人邀请加入，需要本人approve
        if find_user.user_id ~= user_info.user_id then
            return user_handler.ack_error(_peer_ctx, 0,
                                        string.format("apply_user_id = %d, current_user_id = %d, find_user_id = %d",
                                                        _msg.apply_group_id, user_info.user_id, find_user.user_id))
        end
    elseif find_user.operate_state == OFFICIAL_GROUP_MEMBER then -- 已经approve
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_id = %d already member in group_id = %d", find_user.user_id,  _msg.apply_group_id))
    else
        return user_handler.ack_error(_peer_ctx, 0,
                    string.format("apply_group_id = %d, apply_user_id = %d, user_id = %d", _msg.apply_group_id,  _msg.apply_user_id, user_info.user_id))
    end
    local update_res = mysql_client:update_condition("group_user", { operate_state = OFFICIAL_GROUP_MEMBER },
                                                        { group_id = _msg.apply_group_id, user_id = _msg.apply_user_id })
    if not update_res then
        return user_handler.ack_error(_peer_ctx, 0,
                                      string.format("apply_user_id = %d, apply_group_id = %d, error = %s",
                                                    _msg.apply_user_id, _msg.apply_group_id, mysql_client.last_error_))
    end
    
    group_handler.add_user_msg(_peer_ctx, _msg.apply_group_id,
                                        string.format("approve_user_id = %d approve user_id = %d join group_id = %d ",
                                                    user_info.user_id, _msg.apply_user_id, _msg.apply_group_id))

    local ack_approve_dict = { approve_result = 0, approve_error = "" }
    user_handler.send_data(_peer_ctx, ack_approve_dict)
    return true
end

function group_handler.refuse_join(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.refuse_group_id) ~= "number" or type(_msg.refuse_user_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("refuse_group_id = %s, refuse_user_id = %s", type(_msg.refuse_group_id), type(_msg.refuse_user_id)))
    end
    local query_res = mysql_client:read_condition("group_user", { user_id = _msg.refuse_user_id, group_id = _msg.refuse_group_id})
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local find_user = nil
    if #query_res > 0 then find_user = query_res[1] end

    if not find_user then
        return user_handler.ack_error(_peer_ctx, 0, string.format("not exist user_id = %d, group_id = %d", _msg.refuse_user_id, _msg.refuse_grou_id))
    end
    find_user.operate_state = tonumber(find_user.operate_state)
    if find_user.operate_state == APPLY_JOIN_GROUP then -- 本人申请，需要创建者refuse
        query_res = mysql_client:read_condition("group_chat", { group_id = _msg.refuse_group_id })
        if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
        if #query_res ~= 1 then return user_handler.ack_error(_peer_ctx, 0, string.format("refuse_group_id = %d, num = %d", _msg.refuse_group_id, #query_res)) end
        local owner_user_id = tonumber(query_res[1].owner_user_id)
        if user_info.user_id ~= owner_user_id then
            return user_handler.ack_error(_peer_ctx, 0,
                                        string.format("refuse_user_id = %d, current_user_id = %d, owner_user_id = %d",
                                                        _msg.refuse_group_id, user_info.user_id, owner_user_id))
        end
    elseif find_user.operate_state == INVITE_JOIN_GROUP then -- 被别人邀请加入，需要本人refuse
        if find_user.user_id ~= user_info.user_id then
            return user_handler.ack_error(_peer_ctx, 0,
                                        string.format("refuse_user_id = %d, current_user_id = %d, find_user_id = %d",
                                                        _msg.refuse_group_id, user_info.user_id, find_user.user_id))
        end
    elseif find_user.operate_state == OFFICIAL_GROUP_MEMBER then -- 已经approve
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_id = %d already member in group_id = %d", find_user.user_id,  _msg.refuse_group_id))
    else
        return user_handler.ack_error(_peer_ctx, 0,
                    string.format("refuse_group_id = %d, refuse_user_id = %d, user_id = %d", _msg.refuse_group_id,  _msg.refuse_user_id, user_info.user_id))
    end
    local delete_res = mysql_client:delete_condition("group_user", { operate_state = OFFICIAL_GROUP_MEMBER },
                                                        { group_id = _msg.apply_group_id, user_id = _msg.apply_user_id })
    if not delete_res then
        return user_handler.ack_error(_peer_ctx, 0,
                                      string.format("delete_user_id = %d, delete_group_id = %d, error = %s",
                                                    _msg.delete_user_id, _msg.delete_group_id, mysql_client.last_error_))
    end

    group_handler.add_user_msg(_peer_ctx, _msg.refuse_group_id,
                                        string.format("refuse_user_id = %d refuse user_id = %d join group_id = %d ",
                                                    user_info.user_id, _msg.refuse_user_id, _msg.refuse_group_id))
    
    local ack_refuse_dict = { refuse_result = 0, refuse_error = "" }
    user_handler.send_data(_peer_ctx, ack_refuse_dict)
    return true
end

function group_handler.dismiss_group(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.dismiss_group_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("dismiss_group_id = %s", type(_msg.dismiss_group_id)))
    end
    local query_res = mysql_client:read_condition("group_chat", { group_id = _msg.dismiss_group_id, owner_user_id = user_info.user_id })
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    if #query_res ~= 1 then return user_handler.ack_error(_peer_ctx, 0, string.format("you don't group(%d) owner", _msg.dismiss_group_id)) end
    
    local dismiss_user_ids = { }
    query_res = mysql_client:read_condition("group_user", { group_id = _msg.dismiss_group_id })
    if #mysql_client.last_error_ > 0 then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    for _, dismiss_group_user in pairs(query_res) do
        table.insert(dismiss_user_ids, dismiss_group_user.user_id)
    end

    local dismiss_troy_ids = { }
    query_res = mysql_client:read_condition("group_troy", { group_id = _msg.dismiss_group_id })
    if #mysql_client.last_error_ > 0 then
        return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_)
    end
    for _, dismiss_group_troy in pairs(query_res) do
        table.insert(dismiss_troy_ids, tonumber(dismiss_group_troy.troy_id))
    end

    local delete_res = mysql_client:delete_condition("group_user", { group_id = _msg.dismiss_group_id })
    if not delete_res then
        return user_handler.ack_error(_peer_ctx, 0, string.format("group_user dismiss_group_id = %d, error = %s",
                                                                    _msg.dismiss_group_id, mysql_client.last_error_))
    end

    delete_res = mysql_client:delete_condition("group_troy", { group_id = _msg.dismiss_group_id }) 
    if not delete_res then
        return user_handler.ack_error(_peer_ctx, 0,
                                    string.format("group_troy dismiss_group_id = %d, error = %s", _msg.dismiss_group_id, mysql_client.last_error_))
    end

    local update_res = mysql_client:update_condition("group_chat", { owner_user_id = 0 }, { group_id = _msg.dismiss_group_id })
    if not update_res then
        return user_handler.ack_error(_peer_ctx, 0, string.format("group_chat dismiss_group_id = %d, error = %s",
                                        _msg.dismiss_group_id, mysql_client.last_error_))
    end 
    
    group_handler.add_user_msg(_peer_ctx, _msg.dismiss_group_id,
                                                    string.format("dismiss_user_id = %d dismiss group_id = %d ",
                                                                    user_info.user_id, _msg.dismiss_group_id))

    local ack_dismiss_dict = { dismiss_result = 0, dismiss_error = "" }
    user_handler.send_data(_peer_ctx, ack_dismiss_dict)
    return true
end

function group_handler.send_chat_msg(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end

    if type(_msg.group_id) ~= "number" or type(_msg.chat_msg) ~= "string" then
        return troy_handler.ack_error(_peer_ctx, 0, string.format("group_id type is %s, chat_msg type is %s", type(_msg.group_id), type(_msg.chat_msg)))
    end
    local query_res = mysql_client:read_condition("group_user", { user_id = user_info.user_id, group_id = _msg.group_id})
    if not query_res or #query_res ~= 1 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_id = %d, group_id = %d may be not join group", user_info.user_id, _msg.group_id))
    end
    local guser_info = query_res[1]
    guser_info.group_id = tonumber(guser_info.group_id)
    guser_info.operate_state = tonumber(guser_info.operate_state)
    if guser_info.group_id ~= _msg.group_id and guser_info.operate_state ~= OFFICIAL_GROUP_MEMBER then
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_id = %d, group_id = %d, state = %d may be not join group",
                                                                user_info.user_id, _msg.group_id, guser_info.operate_state))
    end
    group_handler.add_user_msg(_peer_ctx, _msg.group_id, _msg.chat_msg)
    local chat_msg = {}
    chat_msg.chat_result = 0
    chat_msg.chat_error = ""
    user_handler.send_data(_peer_ctx, chat_msg)
    return true
end

return group_handler
