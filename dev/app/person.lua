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
	local httpc = http.new()
	local client_id="Hbk9mhQpnDtCfNCBx82DZvh4"
	local client_secret= "cac9e8e002b4d8212426be3b511e5ee6"
	local url = string.format("https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=%s&client_secret=%s", client_id, client_secret)
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,		--https的要写这个
		})
	if res.status ~= ngx.HTTP_OK then 
		return
	end
	local body_data = cjson.decode(res.body)
	if not body_data then 
		return false 
	end
	person_handler.baidu_voice_token = body_data.access_token

	local request_body = string.format('{"format":"%s","rate":%d,"channel":%d,"token":"%s","cuid":"%s","speech":"%s", "len":%d}',
	"pcm", 8000, 1, person_handler.baidu_voice_token, "00:0c:29:5c:c9:56", _msg["file"], _msg["file_len"])

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

    local ack_upload_dict = { }
    ack_upload_dict.user_result = -1
    ack_upload_dict.user_error = "request error"
    if res.body then
        ack_upload_dict.user_result = 0
        ack_upload_dict.text_info_list = res.body
    end

    person_handler.send_data(_peer_ctx, ack_upload_dict)
    return true

end

function person_handler.down_voice(_peer_ctx, _msg)
	local httpc = http.new()
	local client_id="Hbk9mhQpnDtCfNCBx82DZvh4"
	local client_secret= "cac9e8e002b4d8212426be3b511e5ee6"
	local url = string.format("https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=%s&client_secret=%s", client_id, client_secret)
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,		--https的要写这个
		})
	if res.status ~= ngx.HTTP_OK then 
		return
	end
	local body_data = cjson.decode(res.body)
	if not body_data then 
		return false 
	end
	person_handler.baidu_voice_token = body_data.access_token
	local baike_info = person_handler.get_baike_info(_msg["text"])
	local url = string.format("http://tsn.baidu.com/text2audio?tex=%s&lan=zh&cuid=00:0c:29:5c:c9:56&ctp=1&tok=%s", baike_info, person_handler.baidu_voice_token)
	print(url)

	--[[
	local request_body = string.format('{"tex":"%s","lan":"zh","tok":"%s","cuid":"%s","ctp":2}',
	_msg["text"], person_handler.baidu_voice_token, "00:0c:29:5c:c9:56")
	print(request_body)

    local httpc = http.new()
	local res, err = httpc:request_uri("http://tsn.baidu.com/text2audio",{
		method = "POST",
		headers = {
			["Content-Type"] = "application/json; charset=utf-8";
			["Content-Length"] = #request_body;
			},
		body = request_body, --需要用json格式
	})
	print(res.body)
	--]]
    local ack_down_dict = { }
    ack_down_dict.user_result = -1
    ack_down_dict.user_error = ""
    if res.body then
        ack_down_dict.user_result = 0
        ack_down_dict.voice_info_list = url
    end

    person_handler.send_data(_peer_ctx, ack_down_dict)
    return true
end

function person_handler.get_baike_info(_text)
	local url = string.format("http://baike.baidu.com/api/openapi/BaikeLemmaCardApi?scope=103&format=json&appid=379020&bk_key=%s&bk_length=600", _text)
	local httpc = http.new()
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,
		})
	if res.status ~= ngx.HTTP_OK then 
		return
	end
	local body_data = cjson.decode(res.body)
	if not body_data then 
		return false 
	end
	return body_data.abstract or "无返回"
end

function person_hander.search_info(_word)
	--1, 先从库里找
	local query_dict = {key_word = _word}
    local ret = mysql_client:read_condition_not_check("key_word_index", _msg.query_dict)
	local search_num = 0
	if ret then
		search_num = res.search_num
	end

	local info = {}
	if not ret then
		--2, 如果没条目, 查百科
		local text_info = person_hander.get_baike_info(_word)
		if text_info then
			local cate = get_categroy(text_info)
		else
			--百科没有的, 归类到日常, 需要入工输入信息
			local cate = "日常"
		end

		--3, 入库
		local index_insert_dict = {key_word=_word, categroy = cate, search_num = search_num, weighti = 0}
		ret = mysql_client:insert_not_check("key_word_index", index_insert_dict)

		local info_insert_dict = {key_word=_word, info = text_info, type = is_voice and "voice" or "text"}	--后期加入语音数据
		ret = mysql_client:insert_not_check("key_word_info", info_insert_dict, {info="MediumBlob"})

		info = {info = text_info, type = "text"}
	else
    	local ret = mysql_client:read_condition_not_check("key_word_info", _msg.query_dict)
		info = ret
	end

	--对该词的搜索次数加1
	local insert_data = {search_num = search_num+1}
    ret = mysql_client:insert_not_check("key_word_index", insert_data, nil, query_dict)

	-- 终端输出
	local ret_info = {}
	if info.type == "text" then
		--返回语音合成url
		ret_info = string.format("http://tsn.baidu.com/text2audio?tex=%s&lan=zh&cuid=00:0c:29:5c:c9:56&ctp=1&tok=%s", info.info, person_handler.baidu_voice_token)
	else
		--直接返回语音数据
		ret_info = info.info
	end
    person_handler.send_data(_peer_ctx, ret_info)
end


return person_handler
