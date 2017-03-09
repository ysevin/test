local cjson = require "cjson"
local http = require "resty.http"
local mysql_client = require "mysql_client"
local cache_client = require "cache_client"

local person_handler = { }
person_handler._VERSION = '1.0'

person_handler.baidu_voice_token = person_handler.baidu_voice_token or ""

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
	if person_handler.baidu_voice_token == "" then
		local httpc = http.new()
		local client_id="Hbk9mhQpnDtCfNCBx82DZvh4"
		local client_secret= "cac9e8e002b4d8212426be3b511e5ee6"
		local url = string.format("https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=%s&client_secret=%s", client_id, client_secret)
		local res, err = httpc:request_uri(url,{
			ssl_verify = false,		--https的要写这个
			})
		--local res, err = httpc:request_uri("http://www.baidu.com")
		if res.status ~= ngx.HTTP_OK then 
			return
		end
		local body_data = cjson.decode(res.body)
		if not body_data then 
			return false 
		end
		person_handler.baidu_voice_token = body_data.access_token
	end

	--[[
	buffer["format"]  = "pcm";
	buffer["rate"]    = 8000;
	buffer["channel"] = 1;
	buffer["token"]   = token.c_str();
	buffer["cuid"]    = "00:0c:29:5c:c9:56";
	buffer["speech"]  = decode_data;
	buffer["len"]     = content_len;
	--]]

	local request_body = string.format('{"format":"%s","rate":%d,"channel":%d,"token":"%s","cuid":"%s","speech":"%s"}',
	"pcm", 8000, 1, person_handler.baidu_voice_token, "00:0c:29:5c:c9:56", "xxx")
	print("===", request_body)

    local httpc = http.new()
	local res, err = httpc:request_uri("http://vop.baidu.com/server_api",{
		method = "POST",
		headers = {
			["Content-Type"] = "application/json; charset=utf-8";
			["Content-Length"] = #request_body;
			},
		body = request_body, --需要用json格式
	})
	print(res.body)

end


return person_handler

