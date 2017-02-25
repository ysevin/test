local cjson = require "cjson"
local mysql_client = require "mysql_client"
local recommend_handler = { }
recommend_handler._VERSION = '1.0'

function recommend_handler.create_recommend(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.content_list) ~= "string" or type(_msg.event_start_sec) ~= "number" or type(_msg.event_finish_sec) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invalid recmmend = %s, %s, %s", tostring(_msg.content_list), tostring(_msg.event_start_sec), tostring(_msg.event_finish_sec)))
    end
    local insert_info = mysql_client:insert("recommend_content", { recommend_id = 0, content_list = _msg.content_list,
                                                                    event_start_sec = _msg.event_start_sec, event_finish_sec = _msg.event_finish_sec })
    if not insert_info or not insert_info.insert_id then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_create_recommed_dict = { recommend_result = insert_info.insert_id, recommend_error = "" }
    user_handler.send_data(_peer_ctx, ack_create_recommed_dict)
    return true
end

function recommend_handler.update_recommend(_peer_ctx, _msg)
    local user_info = _peer_ctx.user_info_
    local user_handler = _peer_ctx.user_handler_
    if user_handler.socket_state ~= SOCKET_LOGIN then return user_handler.ack_error(_peer_ctx, 0, "please login then retry") end
    if type(_msg.recommend_id) ~= "number" or type(_msg.content_list) ~= "string" or type(_msg.event_start_sec) ~= "number" or type(_msg.event_finish_sec) ~= "number" then
        return user_handler.ack_error(_peer_ctx, 0, string.format("invalid recmmend = %s, %s, %s, %s", tostring(_msg.recommend_id), tostring(_msg.content_list), tostring(_msg.event_start_sec), tostring(_msg.event_finish_sec)))
    end

    local update_res = mysql_client:update("recommend_content", { recommend_id = _msg.recommend_id, content_list = _msg.content_list,
                                                                    event_start_sec = _msg.event_start_sec, event_finish_sec = _msg.event_finish_sec })
    if not update_res then return user_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local ack_update_recommend_dict = { recommend_result = 0, recommend_error = "" }
    user_handler.send_data(_peer_ctx, ack_update_recommend_dict)
    return true
end

return recommend_handler
