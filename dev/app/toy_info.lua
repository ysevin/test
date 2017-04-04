local cjson = require "cjson"
local http = require "resty.http"
local mysql_client = require "mysql_clientex"
local cache_client = require "cache_client"
require "util"

local person_handler = { }
person_handler._VERSION = '1.0'

person_handler.baidu_voice_token = ""
local client_id="Hbk9mhQpnDtCfNCBx82DZvh4"
local client_secret= "cac9e8e002b4d8212426be3b511e5ee6"
person_handler.baide_get_token_url = string.format("https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=%s&client_secret=%s", client_id, client_secret)
person_handler.baidu_baike_search_url = "http://baike.baidu.com/api/openapi/BaikeLemmaCardApi?scope=103&format=json&appid=379020&bk_key=%s&bk_length=600"
person_handler.baidu_music_search_url = "http://tingapi.ting.baidu.com/v1/restserver/ting?from=web&version=5.6.5.0&method=baidu.ting.search.catalogSug&format=json&query=%s"
person_handler.baidu_music_info_url = "http://tingapi.ting.baidu.com/v1/restserver/ting?from=web&version=5.6.5.0&method=baidu.ting.song.play&format=json&songid=%d"
person_handler.baidu_upload_voice_url = "http://vop.baidu.com/server_api"
person_handler.baidu_voice_composition_url = "http://tsn.baidu.com/text2audio?tex=%s&lan=zh&cuid=00:0c:29:5c:c9:56&ctp=1&tok=%s"
person_handler.toy_filter_tbl = "toy_filter"
person_handler.toy_index_tbl = "toy_index"
person_handler.toy_info_tbl = "toy_info"
person_handler.toy_db = "toy"

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
    
    local insert_res = mysql_client:insert("person", "person", insert_data, tb_struct)
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
    local get_res = mysql_client:read_condition("person", "person", _msg.query_dict)
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
    local get_res = mysql_client:read_condition("person", "user", _msg.query_dict)
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
	local url = string.format("music/%s", _msg["file_name"])
	local file_path = string.format("../nginx/html/%s", url)
	local file = io.open(file_path, "wb")
	file:write(ngx.decode_base64(_msg["file_content"]))
	file:close()

    local ret_info = {}
    ret_info.toy_info_upload_ret = {}
	if _msg["insert_db"] then
		person_handler.insert_info(_msg["file_key"], url, "voice")

		local query_dict = {key_word = _msg["file_key"]}
    	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_info_tbl, query_dict)
        ret_info.toy_info_update_ret = ret[1]
	end

    person_handler.send_data(_peer_ctx, ret_info)
    return true

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
	local url = string.format(person_handler.baidu_baike_search_url, _word)
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
	local url = string.format(person_handler.baidu_music_search_url, _word)
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

	local url = string.format(person_handler.baidu_music_info_url, songid)
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

	local music_name = string.format("%s.%s", _word, body_data.bitrate.file_extension)
	local music_url = person_handler.download_music(music_name, body_data.bitrate.file_link)
	return music_url
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

function person_handler.download_music(_name, _url)
	local url = _url
	local httpc = http.new()
	local res, err = httpc:request_uri(url,{
		ssl_verify = false,
		})
	if res.status ~= ngx.HTTP_OK then 
		return nil
	end

	local ret_info = {}
	--ret_info.voice_data = ngx.encode_base64(res.body)		--javascript解码后数据不一样!!!
	return person_handler.save_music(_name, res.body)
end

function person_handler.save_music(_name, _data, _base64)
	local url = string.format("music/%s", _name)
	local file_path = string.format("../nginx/html/%s", url)
	local file = io.open(file_path, "wb")
	if _base64 then
		file:write(ngx.decode_base64(_data))
	else
		file:write(_data)
	end
	file:close()
	return url
end

function person_handler.get_self_info(_word)
	local query_dict = {key_word = _word}
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_info_tbl, query_dict)
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

function person_handler.insert_filter(_word, _id)
	--插入到index库
	local query_dict = {word = _word}
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_filter_tbl, query_dict)
	local insert_dict = {word = _word}
	ret = ret or {}
	if not ret[1] then
		ret = mysql_client:insert(person_handler.toy_db, person_handler.toy_filter_tbl, insert_dict)
	else
		local query_dict = {id = _id}
		ret = mysql_client:insert(person_handler.toy_db, person_handler.toy_filter_tbl, insert_dict, nil, query_dict)
	end
	return ret
end

function person_handler.insert_index(_key_word, _word, _weight)
	--插入到index库
	_weight = _weight or 0
	local query_dict = {word = _word, key_word = _key_word}
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_index_tbl, query_dict)
	local insert_dict = {word = _word, key_word = _key_word, weight = _weight, search_num = 0}
	ret = ret or {}
	if not ret[1] then
		ret = mysql_client:insert(person_handler.toy_db, person_handler.toy_index_tbl, insert_dict)
	end
	return ret
end

function person_handler.update_index(_key_word, _word, _weight, _id)
	--插入到index库
	_weight = _weight or 0
	local query_dict = {id = _id}
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_index_tbl, query_dict)
	local insert_dict = {word = _word, key_word = _key_word, weight = _weight}
	ret = ret or {}
	if ret[1] then
		ret = mysql_client:insert(person_handler.toy_db, person_handler.toy_index_tbl, insert_dict, nil, query_dict)
	end
	return ret
end

function person_handler.insert_info(_key_word, _info, _type)
	--入资源库
	local query_dict = {key_word = _key_word}
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_info_tbl, query_dict)
	local insert_dict = {key_word = _key_word, info = _info, type = _type }
	ret = ret or {}
	if not ret[1] then
		ret = mysql_client:insert(person_handler.toy_db, person_handler.toy_info_tbl, insert_dict, {info="MediumBlob"})
	else
		ret = mysql_client:insert(person_handler.toy_db, person_handler.toy_info_tbl, insert_dict, nil, query_dict)
	end
	return ret
end

function person_handler.word_filter(_word)
	local key_words = {}
	table.insert(key_words, _word)
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_filter_tbl)
	if ret then
		for k, v in pairs(ret) do
			local word = string.gsub(_word, v.word, "")
			if word ~= _word then
				table.insert(key_words, word)
			end
		end
	end
	table.sort(key_words, function(str1, str2) return string.len(str1) > string.len(str2) end )
	return key_words
end

function person_handler.search_info(_peer_ctx, _word)
	--先从库里找
	local key_word = nil
	local query_dict = {word = _word}
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_index_tbl, query_dict)
	--根据权重随机一个
	if ret and #ret > 0 then
		local count = 0
		local range_random = {}
		local begin = 0
		for idx, val in pairs(ret) do
			range_random[idx] = {begin, begin + val.weight}
			begin = begin + val.weight
		end
		local r = math.random(begin)
		local sel = 1
		for idx, val in pairs(range_random) do
			if r >= val[1] and r <= val[2] then
				sel = idx
				break
			end
		end
		local find = ret[sel]
		key_word = find.key_word
	end

	local info = {}
	if not key_word then
		local words = person_handler.word_filter(_word)
		local len = #words
		ss(words)
		for i=1, len do
			local word = words[i]
			local inf, ty = person_handler.search_info_one(word)
			if inf then
				key_word = word
				info.info = inf
				info.type = ty
				break
			end
		end

		if key_word then
			person_handler.insert_info(key_word, info.info, info.type)
		end

		key_word = key_word or "日常回答"
		if key_word ~= _word then
			person_handler.insert_index(key_word, _word)		--关键词和用户词相等就没有必要写进去了.
		end
	end

	local query_dict = {key_word = key_word}
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_info_tbl, query_dict)
	if ret and ret[1] then
		info = ret[1]
	end

	--对该词的搜索次数加1
	local query_dict = {word = _word}
    local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_index_tbl, query_dict)
	if ret and ret[1] then
		local find = ret[1]
		local search_num = find.search_num or ""
		search_num = tonumber(search_num) or 0
		local insert_data = {search_num = search_num+1}
		ret = mysql_client:insert(person_handler.toy_db, person_handler.toy_index_tbl, insert_data, nil, query_dict)
	end
	ss(info)

	-- 终端输出
	local ret_info = {}
	if info.type == "text" then
		--返回语音合成url
		person_handler.get_baidu_token()
		ret_info.voice_url = string.format(person_handler.baidu_voice_composition_url, info.info, person_handler.baidu_voice_token)
	else
		--直接返回语音链接
		ret_info.voice_url = info.info
	end
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.voice_test(_peer_ctx, _msg)
	person_handler.search_info(_peer_ctx, _msg["text"])
	return true
end


function person_handler.search_toy_info(_peer_ctx, _msg)
	local query_dict = {}
	if _msg["key_word"] ~= "" then
		query_dict = {key_word = _msg["key_word"]}
	end
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_info_tbl, query_dict)
	local ret_info = {toy_info_list = ret}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.del_toy_info(_peer_ctx, _msg)
	local query_dict = {id = _msg["id"]}
	local ret = mysql_client:delete_condition(person_handler.toy_db, person_handler.toy_info_tbl, query_dict)
	local ret_info = {delete_info_ret = ret and "删除成功" or "删除失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.add_toy_info(_peer_ctx, _msg)
	local query_dict = {key_word = _msg["key_word"], info = _msg["info"]}
	local ret = person_handler.insert_info(_msg["key_word"], _msg["info"], "text")
	local ret_info = {add_info_ret = ret and "添加成功", "添加失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.update_toy_info(_peer_ctx, _msg)
	local ret = person_handler.insert_info(_msg["key_word"], _msg["info"], "text")
	local ret_info = {update_info_ret = ret and "更新成功", "更新失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.search_toy_index(_peer_ctx, _msg)
	local query_dict = {}
	if _msg["word"] ~= "" then
		query_dict = {key_word = _msg["word"]}
	end
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_index_tbl, query_dict)
	local ret_info = {toy_index_list = ret}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.del_toy_index(_peer_ctx, _msg)
	local query_dict = {id = _msg["id"]}
	local ret = mysql_client:delete_condition(person_handler.toy_db, person_handler.toy_index_tbl, query_dict)
	local ret_info = {delete_index_ret = ret and "删除成功", "删除失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.add_toy_index(_peer_ctx, _msg)
	local ret = person_handler.insert_index(_msg["word"], _msg["key_word"], _msg["weight"])
	local ret_info = {add_index_ret = ret and "添加成功", "添加失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.update_toy_index(_peer_ctx, _msg)
	local ret = person_handler.update_index(_msg["word"], _msg["key_word"], _msg["weight"], _msg["id"])
	local ret_info = {update_index_ret = ret and "更新成功", "更新失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.search_toy_filter(_peer_ctx, _msg)
	local query_dict = {}
	if _msg["word"] ~= "" then
		query_dict = {key_word = _msg["word"]}
	end
	local ret = mysql_client:read_condition(person_handler.toy_db, person_handler.toy_filter_tbl, query_dict)
	local ret_info = {toy_filter_list = ret}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.del_toy_filter(_peer_ctx, _msg)
	local query_dict = {id = _msg["id"]}
	local ret = mysql_client:delete_condition(person_handler.toy_db, person_handler.toy_filter_tbl, query_dict)
	local ret_info = {delete_filter_ret = ret and "删除成功", "删除失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.add_toy_filter(_peer_ctx, _msg)
	local ret = person_handler.insert_filter(_msg["word"])
	local ret_info = {add_filter_ret = ret and "添加成功", "添加失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

function person_handler.update_toy_filter(_peer_ctx, _msg)
	local ret = person_handler.insert_filter(_msg["word"], _msg["id"])
	local ret_info = {update_filter_ret = ret and "更新成功", "更新失败"}
    person_handler.send_data(_peer_ctx, ret_info)
	return true
end

return person_handler
