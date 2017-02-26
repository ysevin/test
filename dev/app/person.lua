local cjson = require "cjson"
local http = require "resty.http"
local mysql_client = require "mysql_client"
local cache_client = require "cache_client"

local person_handler = { }
person_handler._VERSION = '1.0'

function person_handler.send_data(_peer_ctx, _data)
    local send_str = cjson.encode(_data)
    local websocket_send_bytes, websocket_send_err = _peer_ctx.websocket_peer_:send_text(send_str)
    if not websocket_send_bytes then ngx.log(ngx.ERR, "send %s failed(%s)", send_str, websocket_send_err) end
end

function person_handler.upload_info(_peer_ctx, _msg)
    local insert_data = { }
	for key, val in pairs(_msg) do
		if key == "phone" then
			val = tonumber(val)
		end
		insert_data[key] = val
	end
	insert_data["fingerprint"] = insert_data["fingerprint"] or "NULL"
	insert_data["photo"] = insert_data["photo"] or "NULL"
    
    local insert_res = mysql_client:insert("persons", insert_data)
    local ack_upload_info_dict = { }
    ack_upload_info_dict.user_result = -1
    ack_upload_info_dict.user_error = mysql_client.last_error_

    if insert_res then
        ack_upload_info_dict.user_result = 0
    end

    person_handler.send_data(_peer_ctx, ack_upload_info_dict)
    return true
end

function person_handler.query_info(_peer_ctx, _msg)
    local get_res = mysql_client:read_condition("persons", _msg.query_dict)
    local ack_get_info_dict = { }
    ack_get_info_dict.user_result = -1
    ack_get_info_dict.user_error = mysql_client.last_error_
    if get_res then
        ack_get_info_dict.user_result = 0
        ack_get_info_dict.person_info_list = get_res
    end

    person_handler.send_data(_peer_ctx, ack_get_info_dict)
    return true
end

return person_handler

