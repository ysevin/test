document.write("<script src=common.js></script>") 
function toy_info_del(id)
{
	var sd = new Array
	sd["id"] = id
	send_data("del_toy_info", sd)
	/*
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"del_toy_info",'

	str += '"id":' + id + ','

	str = str.substring(0, str.length-1)
	str += "}"
	log('del_toy_info: ' + websocket_channel_addr + ", str: " + str);

	websocket_channel.send(str);
	*/

	window.event.returnValue=false;  
}

function toy_info_update_text(arg)
{
	var ar = arg.split("|");
	var text = document.getElementById("text_" + ar[0]);
	var sd = new Array
	sd["key_word"] = ar[1]
	sd["info"] = text.value
	send_data("update_toy_info", sd)

	/*
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"update_toy_info",'

	var ar = arg.split("|");
	var text = document.getElementById("text_" + ar[0]);
	str += '"key_word":"' + ar[1] + '",'
	str += '"info":"' + text.value + '",'


	str = str.substring(0, str.length-1)
	str += "}"
	log('update_toy_info: ' + websocket_channel_addr + ", str: " + str);

	websocket_channel.send(str);
	*/

	window.event.returnValue=false;  
}

function toy_info_update_music(arg)
{
	var ar = arg.split("|");
	upload_voice(ar[0], ar[1], true)
}

function toy_info_add_text()
{
	var word = document.getElementById("text_word");
	var info = document.getElementById("text_info");

	var sd = new Array
	sd["key_word"] = word.value
	sd["info"] = info.value
	send_data("add_toy_info", sd)

	/*
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"add_toy_info",'

	var word = document.getElementById("text_word");
	var info = document.getElementById("text_info");
	str += '"key_word":"' + word.value + '",'
	str += '"info":"' + info.value + '",'
	str += '"type":"text",'

	str = str.substring(0, str.length-1)
	str += "}"
	log('add_toy_info: ' + websocket_channel_addr + ", str: " + str);

	websocket_channel.send(str);
	*/

	window.event.returnValue=false;  
}
function toy_info_add_music(file_id)
{
	if(voice_file[file_id] != null)
	{
		var word = document.getElementById("music_word");
		upload_voice(file_id, word.value, true)
	}
	else
	{
		log('先占击打开按钮,选择音乐')
	}
	window.event.returnValue=false;  
}

function toy_info_search()
{
	var word = document.getElementById("search_text");
	var sd = new Array
	sd["key_word"] = word.value
	send_data("search_toy_info", sd)

	/*
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"search_toy_info",'

	var word = document.getElementById("search_text");
	str += '"key_word":"' + word.value + '",'

	str = str.substring(0, str.length-1)
	str += "}"
	log('search_toy_info: ' + websocket_channel_addr + ", str: " + str);

	websocket_channel.send(str);
	*/
	window.event.returnValue=false;  
}

function toy_info_form_recv(str)
{
	var obj = JSON.parse(str);
	if(obj.toy_info_update_ret)
	{
		var info = obj.toy_info_update_ret
		var au = document.getElementById("audio_" + info.id)
	}
	else if(obj.toy_info_list)
	{
		var tb_ar = new Array()
		for(var idx in obj.toy_info_list)
		{
			var ar = new Array()
			var info = obj.toy_info_list[idx]
			ar[0] = "l," + info["key_word"]
			if(info["type"] == "voice")
			{
				ar[1] = 'v,audio_'+ info["id"] + ',' + info["info"]
				ar[2] = "b,删除,toy_info_del(" + info["id"] + ")"
				var arg = 'voice_file_' + info["id"] + "|" + info["key_word"]
				ar[3] = "b,更新,toy_info_update_music('" + arg + "')"
				ar[4] = "vf,voice_file_" + info["id"]
			}
			else
			{
				ar[1] = "i,text_"+ info["id"] + "," + info["info"]
				ar[2] = "b,删除,toy_info_del(" + info["id"] + ")"
				var arg = info["id"] + "|" + info["key_word"]
				ar[3] = "b,更新,toy_info_update_text('" + arg + "')"
			}
			tb_ar[idx] = ar
		}
		var di = document.getElementById("div_search")
		if(di)
			di.parentNode.removeChild(di)

		var lfo = document.getElementById("toy_info_form")
		di = document.createElement("div_search")
		di.id = "div_search"
		lfo.appendChild(di)
		create_table_control(di.id, null, tb_ar)
	}
}
function create_toy_info_form(parent_id)
{
	var fo = document.getElementById(parent_id)

	var lfo = document.createElement("form")
	lfo.id = "toy_info_form"
	fo.appendChild(lfo)

	var di = document.createElement("div")
	di.id = "div1"
	lfo.appendChild(di)
	var text_ar = [
		["i,text_word","i,text_info","b,添加文本,toy_info_add_text()"],
		["i,music_word","vf,voice_file","b,添加语音,toy_info_add_music('voice_file')"],
	]
	create_table_control(di.id, null, text_ar)

	lfo.appendChild(document.createElement("br"))

	di = document.createElement("div")
	di.id = "div2"
	lfo.appendChild(di)
	var text_ar = [
		["i,search_text","b,搜索,toy_info_search()"],
	]
	create_table_control(di.id, null, text_ar)

	connect()
}
