var websocket_channel_addr = "ws://10.251.120.192:8080/toy_info_main";
var websocket_channel = null;

var voice_file = new Array()
var recv_func = new Array()

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

function register_recv_func(form_name, func)
{
	recv_func[form_name] = func
}

function recv(str)
{
	for(var name in recv_func)
	{
		var fo = document.getElementById(name)
		if(fo && recv_func[name])
		{
			recv_func[name](str)
			break
		}
	}
}
function log(text)
{
	var li = document.createElement('li')
	li.appendChild(document.createTextNode(text));
	document.getElementById('log').appendChild(li)
	return false;
}

function send(cmd, data_dict)
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
function read_file(file_id, img_id)
{
	var files = document.getElementById(file_id).files
	var file = files[0];
	var maxsize = 64 * 1024;

	// 接受 jpeg, jpg, png 类型的图片
	if (!/\/(?:jpeg|jpg|png)/i.test(file.type)) return;

	var reader = new FileReader();
	reader.onload = function() {
		var result = this.result;
		var img = new Image();

		// 如果图片小于 64kb，不压缩
		if (result.length <= maxsize) {
			to_previewer(file_id, img_id, result)
			return;
		}

		img.onload = function() {
			var compressedDataUrl = compress(img, file.type);
			to_previewer(file_id, img_id, compressedDataUrl)
			img = null;
		};

		img.src = result;
	};

	reader.readAsDataURL(file);
}

function to_previewer(file_id, img_id, dataUrl) {
	var file = document.getElementById(file_id);
	var img = document.getElementById(img_id);
	img.src = dataUrl;
	file.value = '';
}

function compress(img, fileType) {
	var canvas = document.createElement("canvas");
	var ctx = canvas.getContext('2d');

	var width = img.width;
	var height = img.height;

	canvas.width = width;
	canvas.height = height;

	ctx.fillStyle = "#fff";
	ctx.fillRect(0, 0, canvas.width, canvas.height);
	ctx.drawImage(img, 0, 0, width, height);

	// 压缩
	var base64data = canvas.toDataURL(fileType, 0.1);
	canvas = ctx = null;

	return base64data;
}

function download_file(fileName, content){
	if(!fileName)
		fileName = "temp.txt"
	if(!content)
		//content = "hello world"
		content = base64decode(voice_content)
    var aLink = document.createElement('a');
    var blob = new Blob([content]);
    var evt = document.createEvent("HTMLEvents");
    evt.initEvent("click", false, false);//initEvent 不加后两个参数在FF下会报错
    aLink.download = fileName;
    aLink.href = URL.createObjectURL(blob);
    aLink.dispatchEvent(evt);
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
function create_table_control(form_id, ar)
{
	var fo = document.getElementById(form_id)
	var tb = document.createElement("table")
	tb.border = 1
	for(var i=0; i<ar.length; i++)
	{
		var tr = document.createElement("tr")
		tr.id = "tr_" + i
		//th.rowSpan = ar.length		//在javascript中访问属性是大小写区分的。
		for(var j=0; j<ar[i].length; j++)
		{
			var td = document.createElement("td")
			td.align = "center"
			td.id = "td_" + i + "_" + j
			var newar = new Array()
			if(Array.isArray(ar[i][j]))
				newar = ar[i][j]
			else
				newar.push(ar[i][j])
			for(var k=0; k<newar.length; k++)
			{
				var ele = create_my_element(newar[k])
				td.appendChild(ele)
			}
			tr.appendChild(td)
		}
		tb.appendChild(tr)
	}
	fo.appendChild(tb)
}
function create_text_control(parent_id, ar)
{
	var fo = document.getElementById(parent_id)
	fo.appendChild(document.createElement("br"))
	for(var i=0; i<ar.length; i++)
	{
		for(var j=0; j<ar[i].length; j++)
		{
			var ele = create_my_element(ar[i][j])
			fo.appendChild(ele)
		}
		fo.appendChild(document.createElement("br"))
	}
}

function create_input_element(ar, div_id)
{
	/*
	<div class="col-sm-4 placeholder">
		<div class="input-group">
			<span class="input-group-addon">中文姓名</span>
			<input type="text" class="form-control" placeholder="twitterhandle">
		</div>
	</div>
	*/
	var d = document.getElementById(div_id || "div_123")
	var d1 = document.createElement("div")
	d1.className = "col-sm-5 placeholder"
	var d2 = document.createElement("div")
	d2.className = "input-group"
	for(var i=0; i<ar.length; i++)
	{
		if(ar[i] == "input")
		{
			var input = document.createElement("input")
			input.type = "text"
			input.className = "form-control"
			input.placeholder = "twitterhandle"
			d2.appendChild(input)
		}
		else
		{
			var s = document.createElement("span")
			s.className = "input-group-addon"
			s.innerHTML = ar[i]
			d2.appendChild(s)
		}
	}
	d1.appendChild(d2)
	d.appendChild(d1)
}

function create_table_line_element(ar)
{
	var tb = document.getElementById("tbody_123")
	var tr = document.createElement("tr")

	var td = document.createElement("td")
	var a = document.createElement("a")
	a.className = "btn btn-default"
	a.innerHTML = "查看"
	td.appendChild(a)
	tr.appendChild(td)

	ar = ar || ["1,002", "amet", "consectetur", "adipiscing", "elit","1,002", "amet", "consectetur", "adipiscing", "elit","1,002", "amet", "consectetur", "adipiscing", "elit", "elit"]
	for(var i=0; i<ar.length; i++)
	{
		var td = document.createElement("td")
		td.innerHTML = ar[i]
		tr.appendChild(td)
	}

	tb.appendChild(tr)
}

function create_table_element(ar, div_id)
{
	/*
  <table class="table table-bordered">
	<thead>
	  <tr>
		<th></th>
		<th>姓名</th>
		<th>居留证号码</th>
		<th>联系方式</th>
		<th>关系</th>
	  </tr>
	</thead>
	<tbody>
	  <tr>
		<td rowspan="4" width="10">同行人员</td>
		<td width="100">
			<input type="text" class="form-control" placeholder="twitterhandle">
		</td>
		*/
	var div = document.getElementById(div_id || "div_456")
	var tb = document.createElement("table")
	tb.className = "table table-bordered"
	var tbody = document.createElement("tbody")
	for(var i=0; i < ar.length; i++)
	{
		var tr = document.createElement("tr")
		for(var j=0; j<ar[i].length; j++)
		{
			var td = document.createElement("td")
			var strs = new Array();
			strs = ar[i][j].split("|");
			var strss = strs[0].split(",")
			if(strss && strss[0])
				td.colSpan = strss[0]
			if(strss && strss[1])
				td.rowSpan = strss[1]
			if(strss && strss[2])
				td.width = strss[2]

			strs[1] = strs[1] || strs[0]
			if(strs[1] == "i")
			{
				var input = document.createElement("input")
				input.type = "text"
				input.className = "form-control"
				input.placeholder = "twitterhandle"
				td.appendChild(input)
			}
			else
			{
				td.innerHTML = strs[1]
			}
			tr.appendChild(td)
		}
		tbody.appendChild(tr)
	}
	tb.appendChild(tbody)
	div.appendChild(tb)
}
