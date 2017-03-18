local cjson = require "cjson"
local http = require "resty.http"
local mysql_client = require "mysql_client"
local cache_client = require "cache_client"
require "util"

local person_handler = { }
person_handler._VERSION = '1.0'

person_handler.baidu_voice_token = ""

function person_handler.send_data(_peer_ctx, _data)
    local send_str = cjson.encode(_data)
    local websocket_send_bytes, websocket_send_err = _peer_ctx.websocket_peer_:send_text(send_str)
    if not websocket_send_bytes then ngx.log(ngx.ERR, "send %s failed(%s)",send_str, websocket_send_err) end
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
	 _msg["file_ext"],tonumber(_msg["file_rate"]), 1, person_handler.baidu_voice_token, "00:0c:29:5c:c9:56", _msg["file"], _msg["file_len"])

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

function person_handler.add_info(_peer_ctx, _msg)
	person_handler.insert_info(_msg["key_word"], _msg["info"], "text")
end

function person_handler.down_voice(_peer_ctx, _msg)
	--person_handler.download_music(_peer_ctx, _msg)
	--local song = person_handler.get_baidu_music(_msg["text"])
	--local ret_info = {}
	--ret_info.voice_info_list = song
    --person_handler.send_data(_peer_ctx, ret_info)

	person_handler.search_info(_peer_ctx, _msg["text"])

	--[[
	local insert_dict = {word="我想听刻舟求剑", key_word = "刻舟求剑",search_num = 0, weight = 0}
    --local ret = mysql_client:insert_not_check("troy_info_index", insert_dict)
	local query_dict = {word="我想听刻舟求剑xxxx"}
    local ret = mysql_client:read_condition_not_check("troy_info_index", query_dict)
	--local ret = cjson.encode(ret)
	ss(ret)
	--]]


	--[[
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

    local ack_down_dict = { }
    ack_down_dict.user_result = -1
    ack_down_dict.user_error = ""
    if res.body then
        ack_down_dict.user_result = 0
        ack_down_dict.voice_info_list = url
    end

    person_handler.send_data(_peer_ctx, ack_down_dict)
    return true
	--]]
end

function person_handler.get_baidu_token()
	person_handler.baidu_voice_token = nil
	if not person_handler.baidu_voice_token then
		local httpc = http.new()
		local client_id="Hbk9mhQpnDtCfNCBx82DZvh4"
		local client_secret= "cac9e8e002b4d8212426be3b511e5ee6"
		local url = string.format("https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=%s&client_secret=%s", client_id, client_secret)
		local res, err = httpc:request_uri(url,{
			ssl_verify = false,		--https的要写这个
			})
		if res.status == ngx.HTTP_OK then 
			local body_data = cjson.decode(res.body)
			if body_data then 
				person_handler.baidu_voice_token = body_data.access_token
			end
		end
	end
end

function person_handler.get_baike_info(_word)
	person_handler.get_baidu_token()
	local len = utf8len(_word)
	for i=1, len do
		local word = utf8sub(_word, i, len)
		local info = person_handler.get_baike_info_one(word)
		if info then
			return word, info
		end
	end
	return nil
end

function person_handler.get_baike_info_one(_word)
	local url = string.format("http://baike.baidu.com/api/openapi/BaikeLemmaCardApi?scope=103&format=json&appid=379020&bk_key=%s&bk_length=600", _word)
	local httpc = http.new()
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,
		})
	if res.status ~= ngx.HTTP_OK then 
		return nil
	end
	local body_data = cjson.decode(res.body)
	if not body_data then 
		return nil
	end
	local desc = body_data.desc	--可以根据这个来判断是否是是歌曲,但喜羊羊这些的没有"歌曲"这关键字
	if body_data.abstract then
		return body_data.abstract
	end
	return nil
end

function person_handler.get_baidu_music_one(_word)
	local url = string.format("http://tingapi.ting.baidu.com/v1/restserver/ting?from=web&version=5.6.5.0&method=baidu.ting.search.catalogSug&format=json&query=%s", _word)
	local httpc = http.new()
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,
		})
	if res.status ~= ngx.HTTP_OK then 
		return nil
	end
	local body_data = cjson.decode(res.body)
	if not body_data then 
		return nil
	end
	if not body_data.song then
		return nil
	end

	if not body_data.song[1]then
		return nil
	end
	local songid = body_data.song[1].songid
	local artist = body_data.song[1].artistname

	local url = string.format("http://tingapi.ting.baidu.com/v1/restserver/ting?from=web&version=5.6.5.0&method=baidu.ting.song.play&format=json&songid=%d", songid)
	local httpc = http.new()
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,
		})
	if res.status ~= ngx.HTTP_OK then 
		return nil
	end
	local body_data = cjson.decode(res.body)
	if not body_data then 
		return nil
	end

	if not body_data.bitrate then
		return nil
	end

	local song_url = body_data.bitrate.show_link
	return song_url
end

function person_handler.get_baidu_music(_word)
	person_handler.get_baidu_token()
	local len = utf8len(_word)
	for i=1, len do
		local word = utf8sub(_word, i, len)
		local info = person_handler.get_baidu_music_one(word)
		if info then
			return word, info
		end
	end
	return nil
end

function person_handler.download_music(_peer_ctx, _msg)
	local url = _msg["text"]
	if url == "" then
		url = "http://zhangmenshiting.baidu.com/data2/music/ebf299c153c9cfcc14a1d877daf58cba/64022196/64022196.mp3?xcode=43b5a8c7b760a89926d7084657a59bf4"
	end
	local httpc = http.new()
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,
		})
	if res.status ~= ngx.HTTP_OK then 
		return nil
	end

	local ret_info = {}
	--ret_info.voice_data = ngx.encode_base64(res.body)		--javascript解码后数据不一样!!!
	ret_info.voice_data = res.body
    person_handler.send_data(_peer_ctx, ret_info)
end

function person_handler.get_self_info(_word)
	local query_dict = {key_word = _word}
	local ret = mysql_client:read_condition_not_check("troy_info", query_dict)
	if ret and ret[1] then
		local find = ret[1]
		return find.info, find.type
	end
	return nil
end

function person_handler.search_info_one(_word)
	local info, ty = person_handler.get_self_info(_word)

	if not info then
		info = person_handler.get_baidu_music_one(_word)
		if info then
			return info, "voice"
		end
	end

	if not info then
		local info = person_handler.get_baike_info_one(_word)
		if info then
			return info, "text"
		end
	end
	return info, ty
end

function person_handler.insert_index(_key_word, _word)
	--插入到index库
	local query_dict = {word = _word, key_word = _key_word}
	local ret = mysql_client:read_condition_not_check("troy_info_index", query_dict)
	ret = ret or {}
	if not ret[1] then
		local insert_dict = {word = _word, key_word = _key_word, weight = 0}
		ret = mysql_client:insert_not_check("troy_info_index", insert_dict)
	end
end

function person_handler.insert_info(_key_word, _info, _type)
	--入资源库
	local query_dict = {key_word = _key_word}
	local ret = mysql_client:read_condition_not_check("troy_info", query_dict)
	ret = ret or {}
	if not ret[1] then
		local insert_dict = {key_word = _key_word, info = _info, type = _type }
		ret = mysql_client:insert_not_check("troy_info", insert_dict, {info="MediumBlob"})
	end
end

function person_handler.search_info(_peer_ctx, _word)
	--先从库里找
	local key_word = nil
	local query_dict = {word = _word}
	local ret = mysql_client:read_condition_not_check("troy_info_index", query_dict)
	if ret and ret[1] then
		local find = ret[1]
		key_word = find.key_word
	end

	local info = {}
	if not key_word then
		local len = utf8len(_word)
		for i=1, len do
			local word = utf8sub(_word, i, len)
			local inf, ty = person_handler.search_info_one(word)
			if inf then
				key_word = word
				info.info = inf
				info.type = ty
				break
			end
		end

		key_word = key_word or ""
		person_handler.insert_index(key_word, _word)
		if key_word ~= "" then
			person_handler.insert_info(key_word, info.info, info.type)
		end
	else
		local query_dict = {key_word = key_word}
    	local ret = mysql_client:read_condition_not_check("troy_info", query_dict)
		if ret and ret[1] then
			info = ret[1]
		end
	end

	--对该词的搜索次数加1
	local query_dict = {word = _word}
    local ret = mysql_client:read_condition_not_check("troy_info_index", query_dict)
	if ret and ret[1] then
		local find = ret[1]
		local search_num = find.search_num or ""
		search_num = tonumber(search_num) or 0
		local insert_data = {search_num = search_num+1}
		ss(query_dict)
		ret = mysql_client:insert_not_check("troy_info_index", insert_data, nil, query_dict)
	end

	-- 终端输出
	local ret_info = {}
	if info.type == "text" then
		--返回语音合成url
		person_handler.get_baidu_token()
		ret_info.voice_info_list = string.format("http://tsn.baidu.com/text2audio?tex=%s&lan=zh&cuid=00:0c:29:5c:c9:56&ctp=1&tok=%s", info.info, person_handler.baidu_voice_token)
	else
		--直接返回语音数据
		ret_info.voice_info_list = info.info
	end
    person_handler.send_data(_peer_ctx, ret_info)
end


return person_handler
