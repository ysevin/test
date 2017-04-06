var websocket_channel_addr = "ws://localhost:8080/toy_info_main";
var websocket_channel = null;

var voice_file = new Array()

var voice_content = ""
var voice_len = 0
var voice_ext = "mp3"
var voice_name = "mp3"

var base64EncodeChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
var base64DecodeChars = new Array(
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
        52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1,
        -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
        -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
        41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1);
function base64encode(str) {
    var out, i, len;
    var c1, c2, c3;
    len = str.length;
    i = 0;
    out = "";
    while(i < len) {
        c1 = str.charCodeAt(i++) & 0xff;
        if(i == len)
        {
            out += base64EncodeChars.charAt(c1 >> 2);
            out += base64EncodeChars.charAt((c1 & 0x3) << 4);
            out += "==";
            break;
        }
        c2 = str.charCodeAt(i++);
        if(i == len)
        {
            out += base64EncodeChars.charAt(c1 >> 2);
            out += base64EncodeChars.charAt(((c1 & 0x3)<< 4) | ((c2 & 0xF0) >> 4));
            out += base64EncodeChars.charAt((c2 & 0xF) << 2);
            out += "=";
            break;
        }
        c3 = str.charCodeAt(i++);
        out += base64EncodeChars.charAt(c1 >> 2);
        out += base64EncodeChars.charAt(((c1 & 0x3)<< 4) | ((c2 & 0xF0) >> 4));
        out += base64EncodeChars.charAt(((c2 & 0xF) << 2) | ((c3 & 0xC0) >>6));
        out += base64EncodeChars.charAt(c3 & 0x3F);
    }
    return out;
}
function base64decode(str) {
    var c1, c2, c3, c4;
    var i, len, out;
    len = str.length;
    i = 0;
    out = "";
    while(i < len) {
        /* c1 */
        do {
            c1 = base64DecodeChars[str.charCodeAt(i++) & 0xff];
        } while(i < len && c1 == -1);
        if(c1 == -1)
            break;
        /* c2 */
        do {
            c2 = base64DecodeChars[str.charCodeAt(i++) & 0xff];
        } while(i < len && c2 == -1);
        if(c2 == -1)
            break;
        out += String.fromCharCode((c1 << 2) | ((c2 & 0x30) >> 4));
        /* c3 */
        do {
            c3 = str.charCodeAt(i++) & 0xff;
            if(c3 == 61)
                return out;
            c3 = base64DecodeChars[c3];
        } while(i < len && c3 == -1);
        if(c3 == -1)
            break;
        out += String.fromCharCode(((c2 & 0XF) << 4) | ((c3 & 0x3C) >> 2));
        /* c4 */
        do {
            c4 = str.charCodeAt(i++) & 0xff;
            if(c4 == 61)
                return out;
            c4 = base64DecodeChars[c4];
        } while(i < len && c4 == -1);
        if(c4 == -1)
            break;
        out += String.fromCharCode(((c3 & 0x03) << 6) | c4);
    }
    return out;
}

function connect() 
{
	if (websocket_channel !== null ) 
		return log('already connected');
	websocket_channel = new WebSocket(websocket_channel_addr );
	websocket_channel.onopen = function () 
	{
		log('connected ' + websocket_channel_addr);
	};
	websocket_channel.onerror = function (error) 
	{
		log(error);
	};
	websocket_channel.onmessage = function (e) 
	{
		log('recv: ' + e.data);
		recv(e.data)
	};
	websocket_channel.onclose = function () 
	{
		log('disconnected ' + websocket_channel_addr);
		websocket_channel = null;
	};
	return false;
}
function disconnect() 
{
	if (websocket_channel === null ) 
		return log('already disconnected');
	websocket_channel.close();
	log("request disconnect");
	return false;
}

function recv(str)
{
	var obj = JSON.parse(str);
	fo = document.getElementById("toy_test_form")
	if(fo)
	{
		var text_ar = [
			["v,,"+obj.voice_url],
		]
		create_text_control("toy_test_form", text_ar)

		window.event.returnValue=false;  
		return
	}
}

function log(text)
{
	var li = document.createElement('li')
	li.appendChild(document.createTextNode(text));
	document.getElementById('log').appendChild(li)
	return false;
}

function send_data(cmd, data_dict)
{
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"' + cmd + '",'

	for(var key in data_dict)
		str += '"' + key +  '":"' + data_dict[key] + '",'

	str = str.substring(0, str.length-1)
	str += "}"
	log(cmd + ': ' + websocket_channel_addr + ", str: " + str);

	websocket_channel.send(str);
}

function set_voice_file(file_name, blob, file_rate)
{
	var file_id = "translate_voice_file"
	var strs = file_name.split(".");
	voice_file[file_id] = new Array()
	voice_file[file_id]["voice_name"] = file_name
	voice_file[file_id]["voice_ext"] = strs[strs.length - 1]
	voice_file[file_id]["voice_rate"] = file_rate

	var reader = new FileReader();
	reader.readAsBinaryString(blob);
    reader.onload = function() {
		voice_file[file_id]["voice_len"] = this.result.length
		voice_file[file_id]["voice_content"] = base64encode(this.result)

		translate_voice(file_id)
	}
}

function translate_voice(file_id)
{
	var sd = new Array
	sd["file_ext"] = voice_file[file_id]["voice_ext"]
	sd["file_len"] = voice_file[file_id]["voice_len"]
	sd["file_name"] = voice_file[file_id]["voice_name"]
	sd["file_content"] = voice_file[file_id]["voice_content"]
	sd["file_rate"] = voice_file[file_id]["voice_rate"]
	send_data("translate_voice", sd)

	window.event.returnValue=false;  
}

function read_voice_file(file_id)
{
	var files = document.getElementById(file_id).files
	var file = files[0];
    var reader = new FileReader();
	var strs = file.name.split(".");
	voice_file[file_id] = new Array()
	voice_file[file_id]["voice_name"] = file.name
	voice_file[file_id]["voice_ext"] = strs[strs.length - 1]
    reader.readAsBinaryString(file);
    reader.onload = function() {
		voice_file[file_id]["voice_len"] = this.result.length
		voice_file[file_id]["voice_content"] = base64encode(this.result)
    }
}
function create_my_element(str)
{
	var strs = new Array();
	strs = str.split(",");
	var ele = null
	if(strs[0] == "i")
	{
		ele = document.createElement("input")
		ele.id = strs[1]
		ele.type = "text"
		var value = ""
		if(strs[2])
			value = strs[2]
		ele.value = value
	}
	else if(strs[0] == "t")
	{
		ele = document.createElement("input")
		ele.id = strs[1]
		ele.type = "date"
	}
	else if(strs[0] == "b")
	{
		ele = document.createElement("button")
		var t = document.createTextNode(strs[1]);
		ele.appendChild(t);  
		ele.onclick = function(){eval(strs[2]); }
	}
	else if(strs[0] == "p")
	{
		var img = document.createElement("img")
		img.alt = strs[1]
		img.id = strs[1]
		img.width = "100"
		img.height = "100"
		img.type = "img"
		ele = img
	}
	else if(strs[0] == "f")
	{
		var input = document.createElement("input")
		input.type = "file"
		input.id = strs[1] + "_file"
		input.onchange =  function() {read_file(input.id, strs[1])}
		ele = input
	}
	else if(strs[0] == "vf")
	{
		var input = document.createElement("input")
		input.type = "file"
		input.id = strs[1]
		input.onchange =  function() {read_voice_file(input.id)}
		ele = input
	}
	else if(strs[0] == "v")
	{
		var au = document.createElement("audio")
		au.controls = "controls"		//是否显示播放器
		au.autoplay = 0
		au.id = strs[1]
		au.src = encodeURI(strs[2])
		ele = au
	}
	else if(strs[0] == "a")
	{
		ele = document.createElement("a")
		ele.innerHTML = strs[1]
		ele.href = strs[2]
	}
	else if(strs[0] == "c")
	{
		ele = document.createElement("input")
		ele.type = "checkbox"
		ele.id = strs[1]
		ele.value = strs[2]
	}
	else
	{
		ele = document.createElement("label")
		ele.innerHTML = strs[1]
	}
	return ele
}
function create_table_control(form_id, title, text_ar)
{
	var fo = document.getElementById(form_id)
	var tb = document.createElement("table")
	tb.border = 1
	var la = null
	var max_col = 0
	for(var i=0; i<text_ar.length; i++)
	{
		var tr = document.createElement("tr")
		tr.id = "tr_" + i
		if(la == null && title)
		{
			var th = document.createElement("th")
			th.rowSpan = text_ar.length		//在javascript中访问属性是大小写区分的。
			th.width = 10
			la = create_my_element(title)
			th.appendChild(la)
			tr.appendChild(th)
		}
		max_col = Math.max(max_col, text_ar[i].length)
		for(var j=0; j<text_ar[i].length; j++)
		{
			var td = document.createElement("td")
			td.align = "center"
			td.id = "td_" + i + "_" + j
			var newar = new Array()
			if(Array.isArray(text_ar[i][j]))
				newar = text_ar[i][j]
			else
				newar.push(text_ar[i][j])
			for(var k=0; k<newar.length; k++)
			{
				var ele = create_my_element(newar[k])
				td.appendChild(ele)
			}
			tr.appendChild(td)

			if(text_ar[i].length == 1)
				td.colSpan = max_col
		}
		tb.appendChild(tr)
	}
	fo.appendChild(tb)
}
function create_text_control(parent_id, text_ar)
{
	var fo = document.getElementById(parent_id)
	fo.appendChild(document.createElement("br"))
	for(var i=0; i<text_ar.length; i++)
	{
		for(var j=0; j<text_ar[i].length; j++)
		{
			var ele = create_my_element(text_ar[i][j])
			fo.appendChild(ele)
		}
		fo.appendChild(document.createElement("br"))
	}
}
function create_voice_translate_form(parent_id)
{
	var text_ar = [
		["b,上传,translate_voice('translate_voice_file')"],
		["vf,translate_voice_file"],
	]
	var fo = document.getElementById(parent_id)
	var lfo = document.createElement("form")
	lfo.id = "voice_translate_form"
	fo.appendChild(lfo)
	create_table_control(lfo.id, null, text_ar)

	connect()
}
