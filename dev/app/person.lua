local cjson = require "cjson"
local http = require "resty.http"
local mysql_client = require "mysql_client"
local cache_client = require "cache_client"

local person_handler = { }
person_handler._VERSION = '1.0'

person_handler.baidu_voice_token = ""

function person_handler.send_data(_peer_ctx, _data)
    local send_str = cjson.encode(_data)
    local websocket_send_bytes, websocket_send_err = _peer_ctx.websocket_peer_:send_text(send_str)
    if not websocket_send_bytes then ngx.log(ngx.ERR, "send %s failed(%s)", send_str, websocket_send_err) end
end

function person_handler.upload_info(_peer_ctx, _msg)
    local insert_data = { }
	local tb_struct = {
		photo1 = "MediumBlob",
		photo2 = "MediumBlob",
		photo3 = "MediumBlob",
		fingerprint1= "MediumBlob",
		fingerprint2 = "MediumBlob",
		fingerprint3 = "MediumBlob",
	}
	for key, val in pairs(_msg) do
		if key ~= "websocket_cmd" then
			if val == "" then
				val = "0"
			end
			insert_data[key] = val
		end
	end
    
    local insert_res = mysql_client:insert_not_check("person", insert_data, tb_struct)
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
    local get_res = mysql_client:read_condition_not_check("person", _msg.query_dict)
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

function person_handler.login(_peer_ctx, _msg)
    local get_res = mysql_client:read_condition_not_check("user", _msg.query_dict)
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

function person_handler.upload_voice(_peer_ctx, _msg)
    local http_client = http.new()
	local client_id="Hbk9mhQpnDtCfNCBx82DZvh4"
	local client_secret= "cac9e8e002b4d8212426be3b511e5ee6"
    local http_res, http_err = http_client:request_uri(string.format("https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=%s&client_secret=%s", client_id, client_secret))
    if http_res.status ~= ngx.HTTP_OK then return false end
    local body_data = json.decode(http_res.body)
    if not body_data then 
		return false 
	end
	person_handler.baidu_voice_token = ""

	--[[
	buffer["format"]  = "pcm";
	buffer["rate"]    = 8000;
	buffer["channel"] = 1;
	buffer["token"]   = token.c_str();
	buffer["cuid"]    = "00:0c:29:5c:c9:56";
	buffer["speech"]  = decode_data;
	buffer["len"]     = content_len;
	--]]

	local request_body = string.format("format=%s&rate=%d&channel=%d&token=%s%cuid=%s&speech=%s&len=%s",
	"pcm", 8000, 1, person_handler.baidu_voice_token, "00:0c:29:5c:c9:56", "xxx", string.len(xxx))
	local response_body = {}

	local res, code, response_headers = http.request{
	url = "http://vop.baidu.com/server_api",
	method = "POST",
	headers =
	{
		["Content-Type"] = "application/json; charset=utf-8";
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


return person_handler

