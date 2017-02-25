local cjson = require "cjson"
local mysql_client = require "mysql_client"
local content_handler = { }
content_handler._VERSION = '1.0'

function content_handler.create_content(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.cls_id) ~= "number" or type(_msg.subcls_id) ~= "number" or type(_msg.content_title) ~= "string" or type(_msg.content_data) ~= "string" then
        return user_handler.ack_error(_peer_ctx, 0,
                string.format("cls_id = %s, subcls_id = %s, content_title = %s, content_data = %s",
                tostring(_msg.cls_id), tostring(_msg.subcls_id), tostring(_msg.content_title), tostring(_msg.content_data)))
    end
   
    local check_cls_id = mysql_client:read("content_classify", _msg.cls_id)
    if not check_cls_id or not next(check_cls_id) then
        return user_handler.ack_error(_peer_ctx, 0, string.format("not exist cls_id = %d, error = %s", _msg.cls_id, mysql_client.last_error_))
    end
    local check_subcls_id = mysql_client:read("content_subclassify", _msg.subcls_id)
    if not check_subcls_id or not next(check_subcls_id) then
        return user_handler.ack_error(_peer_ctx, 0, string.format("not exist subcls_id = %d", _msg.subcls_id))
    end
    
    local content_record = { }
    content_record.content_id = 0
    content_record.cls_id = _msg.cls_id
    content_record.subcls_id = _msg.subcls_id
    content_record.content_title = _msg.content_title
    content_record.content_data = _msg.content_data

    local insert_res = mysql_client:insert("content", content_record)
    local ack_insert_content_dict = { }
    ack_insert_content_dict.content_result = -1
    ack_insert_content_dict.content_error = mysql_client.last_error_
    if insert_res then ack_insert_content_dict.content_result = insert_res.insert_id end
    user_handler.send_data(_peer_ctx, ack_insert_content_dict)
    return true
end

function content_handler.get_content(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.content_id) ~= "number" or _msg.content_id <= 0 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_id = %s, content_id = %s", tostring(user_info.user_id), tostring(_msg.content_id)))
    end
    local content_info = mysql_client:read("content", _msg.content_id)
    local ack_get_content_dict = { }
    ack_get_content_dict.content_result = -1
    ack_get_content_dict.content_error = mysql_client.last_error_
    ack_get_content_dict.content_info = cjson.encode(content_info)
    if next(content_info) then ack_get_content_dict.content_result = 0 end
    user_handler.send_data(_peer_ctx, ack_get_content_dict)
    return true
end

function content_handler.get_cls_content(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.cls_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_id = %s, cls_id = %s", tostring(user_info.user_id), tostring(_msg.cls_id)))
    end
    local cls_contents = mysql_client:read_condition("content", { cls_id = _msg.cls_id })
    if not cls_contents then
        return user_handler.ack_error(_peer_ctx, 0,
                    string.format("user_id = %s, cls_id = %d, error = %s  failed", tostring(user_info.user_id), tostring(_msg.cls_id), mysql_client.last_error_))
    end
    local content_summary_list = { }
    for _, content_summary in pairs(cls_contents) do
        table.insert(content_summary_list, { content_id = content_summary.content_id, cls_id = content_summary.cls_id, subcls_id = content_summary.subcls_id, content_title = content_summary.content_title })
    end
    user_handler.send_data(_peer_ctx, { content_result = 0, content_data = content_summary_list })
    return true
end

function content_handler.get_subcls_content(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.cls_id) ~= "number" or type(_msg.subcls_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("user_id = %s, cls_id = %s, subcls_id = %s",
                                        tostring(user_info.user_id), tostring(_msg.cls_id), tostring(_msg.subcls_id)))
    end
    local subcls_contents = mysql_client:read_condition("content", { cls_id = _msg.cls_id, subcls_id = _msg.subcls_id})
    if not subcls_contents then
        return user_handler.ack_error(_peer_ctx, 0,
                    string.format("user_id = %s, cls_id = %d, error = %s  failed", tostring(user_info.user_id), tostring(_msg.cls_id), mysql_client.last_error_))
    end
    local content_summary_list = { }
    for _, content_summary in pairs(subcls_contents) do
        table.insert(content_summary_list, { content_id = content_summary.content_id, cls_id = content_summary.cls_id, subcls_id = content_summary.subcls_id, content_title = content_summary.content_title })
    end
    user_handler.send_data(_peer_ctx, { content_result = 0, content_data = content_summary_list })
    return true
end

function content_handler.remove_content(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.content_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("content_id = %s", tostring(_msg.content_id)))
    end
    local delete_total = mysql_client:delete_condition("content", { content_id = _msg.content_id })
    if not delete_total then
        return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_)
    end
    local ack_delete_content_dict = { }
    ack_delete_content_dict.content_result = delete_total
    user_handler.send_data(_peer_ctx, ack_delete_content_dict)
    return true
end

return content_handler;

