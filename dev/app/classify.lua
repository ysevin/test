local cjson = require "cjson"
local mysql_client = require "mysql_client"
local classify_handler = { }
classify_handler._VERSION = '1.0'

function classify_handler.create_cls(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.cls_name) ~= "string" or #_msg.cls_name < 10 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invalid cls_name = %s", tostring(_msg.cls_name)))
    end
    local insert_info = mysql_client:insert("content_classify", { cls_id = 0, cls_name = _msg.cls_name })
    if not insert_info or not insert_info.insert_id then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_create_cls_dict = { cls_result = insert_info.insert_id, cls_error = "" }
    user_handler.send_data(_peer_ctx, ack_create_cls_dict)
    return true
end

function classify_handler.update_cls(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.cls_id) ~= "number" or type(_msg.cls_name) ~= "string" or #_msg.cls_name < 10 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("cls_id = %s, cls_name = %s", tostring(_msg.cls_id), tostring(_msg.cls_name)))
    end
    local update_res = mysql_client:update("content_classify", { cls_id = _msg.cls_id, cls_name = _msg.cls_name })
    if not update_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_update_cls_dict = { cls_result = 0, cls_error = "" }
    user_handler.send_data(_peer_ctx, ack_update_cls_dict)
    return true
end

function classify_handler.create_subcls(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.cls_id) ~= "number" or type(_msg.subcls_name) ~= "string" or #_msg.subcls_name < 10 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("cls_id = %s, subcls_name = %s", tostring(_msg.cls_id), tostring(_msg.subcls_name)))
    end
    local cls_info = mysql_client:read("content_classify", _msg.cls_id)
    if not cls_info or not next(cls_info) then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end

    local subcls_info = mysql_client:insert("content_subclassify", { subcls_id = 0, cls_id = _msg.cls_id, subcls_name = _msg.subcls_name })
    if not subcls_info or not subcls_info.insert_id then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_create_subcls_dict = { subcls_result = subcls_info.insert_id, subcls_error = "" }
    user_handler.send_data(_peer_ctx, ack_create_subcls_dict)
    return true
end

function classify_handler.update_subcls(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.subcls_id) ~= "number" or type(_msg.subcls_name) ~= "string" or #_msg.subcls_name < 10 then
        return user_handler.ack_error(_peer_ctx, 0, string.format("subcls_id = %s, subcls_name = %s", tostring(_msg.subcls_id), tostring(_msg.subcls_name)))
    end
    local update_res = mysql_client:update("content_subclassify", { subcls_id = _msg.subcls_id, subcls_name = _msg.subcls_name })
    if not update_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_update_subcls_dict = { subcls_result = 0, subcls_error = "" }
    user_handler.send_data(_peer_ctx, ack_update_subcls_dict)
    return true
end

return classify_handler

