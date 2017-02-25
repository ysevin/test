local cjson = require "cjson"
local mysql_client = require "mysql_client"
local fashion_handler = { }
fashion_handler._VERSION = '1.0'

function fashion_handler.create_fashion_cls(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.fashion_cls_name) ~= "string" or #_msg.fashion_cls_name < 10 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invalid fashion_cls_name = %s", tostring(_msg.fashion_cls_name)))
    end
    local insert_info = mysql_client:insert("fashion_cls", { fashion_id = 0, fashion_name = _msg.fashion_cls_name })
    if not insert_info or not insert_info.insert_id then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_create_fashion_cls_dict = { fashion_cls_result = insert_info.insert_id, fashion_cls_error = "" }
    user_handler.send_data(_peer_ctx, ack_create_fashion_cls_dict)
    return true
end

function fashion_handler.update_fashion_cls(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.fashion_cls_id) ~= "number" or type(_msg.fashion_cls_name) ~= "string" or #_msg.fashion_cls_name < 10 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("fashion_id = %s, fashion_cls_name = %s", tostring(_msg.fashion_cls_id), tostring(_msg.fashion_cls_name)))
    end
    local update_res = mysql_client:update("fashion_cls", { fashion_id = _msg.fashion_cls_id, fashion_name = _msg.fashion_cls_name })
    if not update_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_update_fashion_cls_dict = { fashion_cls_result = 0, fashion_cls_error = "" }
    user_handler.send_data(_peer_ctx, ack_update_fashion_cls_dict)
    return true
end

function fashion_handler.create_fashion_content(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.fashion_id) ~= "number" or type(_msg.content_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invalid fashion_id = %s, content_id = %s", tostring(_msg.fashion_id), tostring(_msg.content_id)))
    end
    
    local check_fashion_id = mysql_client:read("fashion_cls", _msg.fashion_id)
    if not check_fashion_id or not next(check_fashion_id) then
        return user_handler.ack_error(_peer_ctx, 0, string.format("not exist fashion_id = %d, error = %s", _msg.fashion_id, mysql_client.last_error_))
    end
    local check_content_id = mysql_client:read("content", _msg.content_id)
    if not check_content_id or not next(check_content_id) then
        return user_handler.ack_error(_peer_ctx, 0, string.format("not exist content_id = %d", _msg.content_id))
    end
 
    local insert_info = mysql_client:insert("fashion_content", { fashion_id = _msg.fashion_id, content_id = _msg.content_id })
    if not insert_info or not insert_info.insert_id then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_create_fashion_content_dict = { cls_result = insert_info.insert_id, cls_error = "" }
    user_handler.send_data(_peer_ctx, ack_create_fashion_content_dict)
    return true
end

function fashion_handler.delete_fashion_content(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end

    if type(_msg.fashion_id) ~= "number" or type(_msg.content_id) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invalid fashion_id = %s, content_id = %s", tostring(_msg.fashion_id), tostring(_msg.content_id)))
    end
    local check_fashion_id = mysql_client:read("fashion_cls", _msg.fashion_id)
    if not check_fashion_id or not next(check_fashion_id) then
        return user_handler.ack_error(_peer_ctx, 0, string.format("not exist fashion_id = %d, error = %s", _msg.fashion_id, mysql_client.last_error_))
    end
    local check_content_id = mysql_client:read("content", _msg.content_id)
    if not check_content_id or not next(check_content_id) then
        return user_handler.ack_error(_peer_ctx, 0, string.format("not exist content_id = %d", _msg.content_id))
    end

    local delete_res = mysql_client:delete_condition("fashion_content", { fashion_id = _msg.fashion_id, content_id = _msg.content_id })
    if not delete_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_delete_fashion_content_dict = { delete_fashion_content_result = 0, delete_fashion_content_error = "" }
    user_handler.send_data(_peer_ctx, ack_delete_fashion_content_dict)
    return true
end

return fashion_handler

