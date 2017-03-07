local cjson = require "cjson"
local mysql_client = require "mysql_client"
local cache_client = require "cache_client"

local troy_handler = { }
troy_handler._VERSION = '1.0'
troy_handler.group_msg_id = 0
troy_handler.troy_id = -1
troy_handler.group_id = -1

function troy_handler.send_data(_peer_ctx, _data)
    local send_str = cjson.encode(_data)
    local websocket_send_bytes, websocket_send_err = _peer_ctx.websocket_peer_:send_text(send_str)
    if not websocket_send_bytes then ngx.log(ngx.ERR, "send %s failed(%s): ", send_str, websocket_send_err) end
end

function troy_handler.ack_error(_peer_ctx, _result, _error_str)
    local ack_troy_dict = { }
    ack_troy_dict.troy_result = _result
    ack_troy_dict.troy_error = _error_str
    troy_handler.send_data(_peer_ctx, ack_troy_dict)
    return _result == 0 or false
end

function troy_handler.connect_server(_peer_ctx, _msg)
    if troy_handler.troy_id >= 0 then return troy_handler.ack_error(_peer_ctx, 0, "设备已经连接") end
    if type(_msg.troy_id) ~= "number" or type(_msg.group_msg_id) ~= "number" then
        return troy_handler.ack_error(_peer_ctx, 0, string.format("troy_id type is %s, group_msg_id type is %s", type(_msg.troy_id), type(_msg.group_msg_id)))
    end
    local query_res = mysql_client:read_condition("troy", { troy_id = _msg.troy_id })
    if not query_res then return troy_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    local troy_num = #query_res
    if troy_num ~= 1 then return troy_handler.ack_error(_peer_ctx, 0, string.format("invalid troy_id = %d, troy_num(%d)", _msg.troy_id, troy_num)) end
    troy_handler.troy_id = _msg.troy_id

    query_res = mysql_client:read_condition("group_troy", { troy_id = _msg.troy_id })
    if not query_res or #query_res <= 0 then return troy_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_) end
    troy_handler.group_id = query_res[1].group_id
    troy_handler.group_msg_id = _msg.group_msg_id

    local troy_info = { }
    troy_info.troy_result = 0
    troy_info.troy_error = ""
    troy_info.info = query_res[1]
    troy_handler.send_data(_peer_ctx, troy_info)
    return true
end

function troy_handler.generate_invite_code(_peer_ctx, _msg)
    if troy_handler.troy_id < 0 then return troy_handler.ack_error(_peer_ctx, 0, "无效设备") end
    local invite_code = math.random(10000, 99999)
    local troy_id, flags = ngx.shared.troy_invite_code:get(invite_code)
    if not troy_id then
        ngx.shared.troy_invite_code:set(invite_code, troy_handler.troy_id, 10000)
    else
        for iter_count = 1, 20, 1 do
            invite_code = math.random(10000, 99999)
            troy_id, flags = ngx.shared.troy_invite_code.get(invite_code)
            if not troy_id or troy_id == troy_handler.troy_id then
                ngx.shared.troy_invite_code:set(invite_code, troy_handler.troy_id, 10000)
                break
            end
        end
    end
    
    local invite_info = {}
    invite_info.troy_result = 0
    invite_info.troy_error = ""
    invite_info.invite_code = invite_code
    
    troy_handler.send_data(_peer_ctx, invite_info)
    return true
end

function troy_handler.send_chat_msg(_peer_ctx, _msg)
    if type(_msg.group_id) ~= "number" or type(_msg.chat_msg) ~= "string" then
        return troy_handler.ack_error(_peer_ctx, 0, string.format("group_id type is %s, chat_msg type is %s", type(_msg.group_id), type(_msg.chat_msg)))
    end
    local query_res = mysql_client:read_condition("group_troy", { troy_id = troy_handler.troy_id })
    if not query_res or #query_res ~= 1 then
        return troy_handler.ack_error(_peer_ctx, 0, string.format("troy_id = %d, group_id = %d may be not join group", troy_handler.troy_id, _msg.group_id))
    end
    local gtroy_info = query_res[1]
    gtroy_info.group_id = tonumber(gtroy_info.group_id)
    if gtroy_info.group_id ~= _msg.group_id then
        ngx.log(ngx.ERR, string.format("%s   %s", type(gtroy_info.group_id), type(_msg.group_id)))
        return troy_handler.ack_error(_peer_ctx, 0, string.format("troy_id = %d, group_id = %d(%d) may be not join group",
                                                                    troy_handler.troy_id, _msg.group_id, gtroy_info.group_id))
    end
    local insert_res = mysql_client:insert("group_chat_msg", { group_msg_id = 0, group_id = _msg.group_id, msg_content = _msg.chat_msg,
                                                                create_user_troy_id = troy_handler.troy_id, create_id_type = 1 })
    if not insert_res then
        return troy_handler.ack_error(_peer_ctx, 0, mysql_client.last_error_)
    end
    cache_client:hset(GROUP_MSGID_KEY, _msg.group_id, insert_res.insert_id)
    local chat_msg = {}
    chat_msg.chat_result = 0
    chat_msg.chat_error = ""
    troy_handler.send_data(_peer_ctx, chat_msg)
    return true
end

function troy_handler.check_task(_peer_ctx, _msg)
    if _msg then return end
    local add_group = cache_client:hget(TROY_GROUPID_HKEY, troy_handler.troy_id)
    if add_group then
        troy_handler.group_id = tonumber(add_group)
        cache_client:hdel(troy_handler.troy_id)
    end

    local last_msg_id = cache_client:hget(GROUP_MSGID_KEY, troy_handler.group_id)
    last_msg_id = last_msg_id and tonumber(last_msg_id)
    if not last_msg_id or last_msg_id <= troy_handler.group_msg_id then return end

    local query_res = mysql_client:read_follow_msg("group_chat_msg", "group_msg_id", troy_handler.group_msg_id, "group_id", troy_handler.group_id)
    if not query_res then
        ngx.log(ngx.ERR, string.format("group_msg_id = %d, group_id = %d, error = %s", troy_handler.group_msg_id, troy_handler.group_id, mysql_client.last_error_))
        return
    end
    if #query_res <= 0 then return end
    troy_handler.group_msg_id = tonumber(query_res[1].group_msg_id)

    local notify_msg_dict = { }
    notify_msg_dict.notify_msg = cjson.encode(query_res[1])
    troy_handler.send_data(_peer_ctx, notify_msg_dict)
    return
end

function tory_handler.tx_qq_register(_peer_ctx, _msg)
    local http_client = http.new()
    local http_res, http_err = http_client:request_uri(string.format("https://graph.qq.com/oauth2.0/me?access_token=%s", _msg.code))
    if http_res.status ~= ngx.HTTP_OK then return false end
    local openid_data = json.decode(http_res.body)
    if not openid_data then return false end

	local request_body = [[login=user&password=123]]
	local response_body = {}

	local res, code, response_headers = http.request{
	url = "http://httpbin.org/post",
	method = "POST",
	headers =
	{
		["Content-Type"] = "application/x-www-form-urlencoded";
		["Content-Length"] = #request_body;
		},
		source = ltn12.source.string(request_body),
		sink = ltn12.sink.table(response_body),
	}
																							  
	print(res)
	print(code)
	if type(response_headers) == "table" then
		for k, v in pairs(response_headers) do
			print(k, v)
		end
	end
	print("Response body:")
	if type(response_body) == "table" then
		print(table.concat(response_body))
	else
		print("Not a table:", type(response_body))
	end
end

return troy_handler

