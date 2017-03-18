var websocket_channel_addr = "ws://localhost:8080/my_main";
var websocket_channel = null;
var text_controls ={
	nationality:"����",
	area:"���ڵ���",
	birthday:"��������",
	gender:"�Ա�", 
	entry:"�뾳ʱ��", 
	company:"��ҵ��λ", 
	phone:"��ϵ��ʽ", 
	remark:"��ע"};
var image_controls = {
	photo:"��Ƭ",
	fingerprint:"ָ��"};
var structure_num = 1;
var voice_content = "xxx"
var voice_len = 0
var voice_ext = "mp3"

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
	window.event.returnValue=false;  
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
function send()
{
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"upload", '

	var elems = document.getElementsByTagName("*");
	for(var i=0;i<elems.length;i++)
	{
		if (elems[i].hasAttribute("id"))
		{
			if(elems[i].type == "text")
				str += '"' + elems[i].id + '":"' + elems[i].value + '",'
			else if(elems[i].type == "img")
				str += '"' + elems[i].id + '":"' + elems[i].src + '",'
		}
	} 
		
	str = str.substring(0, str.length-1)
	//for (var k in text_controls)
	//{
	//	var text = document.getElementById(k)
	//	str += '"' + k + '":"' + text.value + '",'
	//}
	//for (var k in image_controls)
	//{
	//	var image = document.getElementById(k)
	//	str += ', "' + k + '":"' + image.src + '"'
	//}
	str += "}"

	console.log('send: ' + websocket_channel_addr + ", str: " + str);
	websocket_channel.send(str);
	window.event.returnValue=false;  
	return false;
}
function recv(str)
{
	var obj = JSON.parse(str);
	var fo = document.getElementById("login_form")
	if(fo)
	{
		for(var idx in obj.person_info_list)
		{
			var pw = document.getElementById("user_password").value
			var info = obj.person_info_list[idx]
			var real_pw
			if(info.hasOwnProperty("user_password"))
			{
				real_pw = info["user_password"]
				if(real_pw != pw)
					alert("���벻��")
				else
					location.href = "person.html";
			}
		}
		window.event.returnValue=false;  
		return
	}
	fo = document.getElementById("voice_form")
	if(fo)
	{
		if(obj.text_info_list)
		{
			var jv = JSON.parse(obj.text_info_list)
			var te = document.getElementById("voice_text")
			te.value = jv.result[0]
		}
		else if(obj.voice_data)
		{
			//download_file("temp.mp3", base64decode(obj.voice_data))
			download_file("temp.mp3", obj.voice_data)
		}
		else
		{
			var voice = obj.voice_info_list
			var text_ar = [
				["v,"+voice],
			]
			create_text_control("voice_form", text_ar)
		}
		window.event.returnValue=false;  
		return
	}
	for(var idx in obj.person_info_list)
	{
		var info = obj.person_info_list[idx]
		for(var id in info) 
		{
			var ele = document.getElementById(id)
			if(ele && ele.type == "img")
				ele.src = info[id]
			else if(ele)
				ele.value = info[id]
		}
	}
}
function query(msg)
{
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"query", "query_dict":{'

	var elems = document.getElementsByTagName("*");
	for(var i=0;i<elems.length;i++)
	{
		if (elems[i].hasAttribute("id"))
		{
			if(elems[i].type == "text" && elems[i].value != "")
			{
				str += '"' + elems[i].id + '":"' + elems[i].value + '",'
				break
			}
		}
	} 
	str = str.substring(0, str.length-1)
	str += "}}"
	log('query: ' + websocket_channel_addr + ", str: " + str);
	websocket_channel.send(str);
	window.event.returnValue=false;  
}
function empty()
{
	var elems = document.getElementsByTagName("*");
	for(var i=0;i<elems.length;i++)
		if (elems[i].hasAttribute("id"))
			elems[i].value = ""
	window.event.returnValue=false;  
}
function structure()
{
	var elems = document.getElementsByTagName("*");
	for(var i=0;i<elems.length;i++)
	{
		if (elems[i].hasAttribute("id"))
		{
			if(elems[i].type == "text")
				elems[i].value = elems[i].id + structure_num
		}
	} 

	structure_num += 1
	window.event.returnValue=false;  
}
function test()
{
	//var text = document.getElementsByName("fname")[0];		//��, ����һ������
	//console.log('Error: ' + str);
	alert("test")
	window.event.returnValue=false;  
}
function login()
{
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"login", "query_dict":{'

	var in_name = document.getElementById("user_name");
	str += '"' + in_name.id + '":"' + in_name.value + '",'

	str = str.substring(0, str.length-1)
	str += "}}"
	log('query: ' + websocket_channel_addr + ", str: " + str);
	websocket_channel.send(str);
	window.event.returnValue=false;  
}
function log(text)
{
	var li = document.createElement('li')
	li.appendChild(document.createTextNode(text));
	document.getElementById('log').appendChild(li)
	return false;
}
function upload_voice()
{
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"upload_voice",'

	var text = document.getElementById("voice_rate");

	str += '"' + "file_ext" + '":"' + voice_ext + '",'
	str += '"' + "file_rate" + '":"' + text.value + '",'
	str += '"' + "file_len" + '":' + voice_len + ','
	str += '"' + "file" + '":"' + voice_content + '",'

	str = str.substring(0, str.length-1)
	str += "}"
	log('upload_voice: ' + websocket_channel_addr + ", str: " + str);
	websocket_channel.send(str);
	window.event.returnValue=false;  
}
function down_voice()
{
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"down_voice",'

	var in_text = document.getElementById("voice_text");
	str += '"' + "text" + '":"' + in_text.value + '",'

	str = str.substring(0, str.length-1)
	str += "}"
	log('down_voice: ' + websocket_channel_addr + ", str: " + str);
	websocket_channel.send(str);
	window.event.returnValue=false;  
	//http://tsn.baidu.com/text2audio?tex=��ð�&lan=zh&cuid=00:0c:29:5c:c9:56&ctp=1&tok=24.f603c9a942fcf1f73aa5663a96fafc58.2592000.1491805308.282335-9361747
}
function play_voice()
{
	if (websocket_channel === null) 
		return log('please connect first');
	var str = '{ "websocket_cmd":"down_voice",'

	var in_text = document.getElementById("voice_text");
	str += '"' + "text" + '":"' + in_text.value + '",'

	str = str.substring(0, str.length-1)
	str += "}"
	log('play_voice: ' + websocket_channel_addr + ", str: " + str);
	websocket_channel.send(str);
	window.event.returnValue=false;  
}

function read_voice_file(file_id)
{
	var files = document.getElementById(file_id).files
	var file = files[0];
    var reader = new FileReader();
	var strs = file.name.split(".");
	voice_ext = strs[strs.length - 1]
    reader.readAsBinaryString(file);
    reader.onload = function() {
		voice_len = this.result.length
		voice_content = base64encode(this.result)
		log('voice: ' +  voice_content);
    }
}
function read_file(file_id, img_id)
{
	var files = document.getElementById(file_id).files
	var file = files[0];
	var maxsize = 64 * 1024;

	// ���� jpeg, jpg, png ���͵�ͼƬ
	if (!/\/(?:jpeg|jpg|png)/i.test(file.type)) return;

	var reader = new FileReader();
	reader.onload = function() {
		var result = this.result;
		var img = new Image();

		// ���ͼƬС�� 64kb����ѹ��
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

	// ѹ��
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
    evt.initEvent("click", false, false);//initEvent ���Ӻ�����������FF�»ᱨ��
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
		ele.onclick = function(){eval(strs[2]+"()")}
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
		input.id = strs[1] + "_file"
		input.onchange =  function() {read_voice_file(input.id)}
		ele = input
	}
	else if(strs[0] == "v")
	{
		var kao = "http://tsn.baidu.com/text2audio?lan=zh&cuid=00:0c:29:5c:c9:56&ctp=1&tok=24.f603c9a942fcf1f73aa5663a96fafc58.2592000.1491805308.282335-9361747&tex=��ð�"
  		//var kao="http://tsn.baidu.com/text2audio?tex=%E4%BD%A0%E5%A5%BD%E5%95%8A&lan=zh&cuid=00:0c:29:5c:c9:56&ctp=1&tok=24.f603c9a942fcf1f73aa5663a96fafc58.2592000.1491805308.282335-9361747"
		var au = document.createElement("audio")
		au.controls = "controls"		//�Ƿ���ʾ������
		au.autoplay = 1
		var so = document.createElement("source")
		so.src = encodeURI(strs[1])
		so.type = "audio/mpeg"
		au.appendChild(so)
		ele = au
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
		if(la == null && title)
		{
			var th = document.createElement("th")
			th.rowSpan = text_ar.length		//��javascript�з��������Ǵ�Сд���ֵġ�
			th.width = 10
			la = create_my_element(title)
			th.appendChild(la)
			tr.appendChild(th)
		}
		max_col = Math.max(max_col, text_ar[i].length)
		for(var j=0; j<text_ar[i].length; j++)
		{
			var td = document.createElement("td")
			var ele = create_my_element(text_ar[i][j])
			td.align = "center"
			td.appendChild(ele)
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
function create_table()
{
	var title = "l,ͬ����Ա"
	var text_ar = [
		["l,����", "l,����֤����", "l,��ϵ��ʽ", "l,��ϵ"],
		["i,friend_name_1", "i,friend_id_1", "i,friend_phone_1", "i,friend_relation_1"],
		["i,friend_name_2", "i,friend_id_2", "i,friend_phone_2", "i,friend_relation_2"],
		["i,friend_name_3", "i,friend_id_3", "i,friend_phone_3", "i,friend_relation_3"],
	]
	create_table_control("main_form", title, text_ar)
}
function create_image()
{
	var text_ar = [
		["p,photo1", "p,photo2", "p,photo3"],
		["f,photo1", "f,photo2", "f,photo3"],
	]
	create_table_control("main_form", null, text_ar)

	var text_ar = [
		["p,fingerprint1", "p,fingerprint2"],
		["f,fingerprint1", "f,fingerprint2"],
	]
	create_table_control("main_form", null, text_ar)
}
function create_button()
{
	var text_ar = [
		["b,����,connect", "b,�Ͽ�,disconnect", "b,�ϴ�,send", "b,��ѯ,query", "b,���,empty", "b,����, structure"],
	]
	create_text_control("main_form", text_ar)
}
function create_login_form(parent_id)
{
	var text_ar = [
		//["l,�û���", "i,user_name"],
		//["l,����", "i,user_password"],
		//["b,��¼,login"],
		["b,�ϴ�,test_voice"],
		["v,��,read_voice_file"],
	]
	var fo = document.getElementById(parent_id)
	var lfo = document.createElement("form")
	lfo.id = "login_form"
	fo.appendChild(lfo)
	create_table_control(lfo.id, null, text_ar)

	connect()
}
function create_user_form(parent_id)
{
	var text_ar = [
		["l,�û���", "i,user_name"],
		["l,����", "i,user_password"],
		["l,����������", "i,user_password"],
		["b,��ӹ���Ա,test"],
		["b,�޸�����,test"],
	]
	var fo = document.getElementById(parent_id)
	var cfo = document.createElement("form")
	cfo.id = "user_form"
	fo.appendChild(cfo)
	create_table_control(cfo.id, null, text_ar)
}
function create_person_form(parent_id)
{
	var tb_ar = [
		[4,    6, 4, 6, 4,       20, 4,    10],
		[4,    6, 4, 6, 4, 10, 4,    10, 4, 6],
		[4, 4, 2, 4, 6, 4, 10, 4, 6, 4,     10],
		]
	var text_ar = [
		["l,��������", "i,chinese_name","l,�Ա�","i,gender","l,��ҵ����","i,company_address","l,��ϵ��ʽ","i,phone"],
		["l,��������", "i,foreign_name","l,����","i,nation","l,�뾳֤��","i,enter_certificates","l,����","i,certificates_id", "l,��Ч����", "t,validity_time"],
		["l,���", "i,height","l,Ѫ��","i,blood","l,�뾳�ص�","i,enter_place","l,ʱ��","t,enter_date", "l,��������", "i,enter_reason"],
		["l,��������", "i,birthday","l,�Ļ��̶�","i,education", "l,�����ص�","i,address"],
		["l,������", "i,homeplace","l,�ڽ�����","i,religion","l,��������","i,car_type","l,���ƺ�","t,car_number", "l,�����ɳ���", "i,police"],
		["l,����", "i,nationality","l,ְҵ","i,job","l,����������","i,residence_from","l,������","t,residence_end", "l,��Ȼ֤���", "i,residence_num"],
		["l,����֤��", "i,foreign_certificates","l,����","i,person_id","l,����������","i,content_name","l,���֤����","t,content_id"],
		["l,����סַ", "i,foreign_adress","l,������סַ","i,content_address","l,��ϵ��ʽ","i,content_phone"],
		["l,��ע", "i,remark"],
		]
	create_text_control(parent_id, text_ar)
	create_table()
	create_image()
	create_button()
}
function create_voice_form(parent_id)
{
	var text_ar = [
		["b,�ϴ�,upload_voice"],
		["i,voice_rate"],
		["vf,��,read_voice_file"],
		["i,voice_text"],
		["b,����,down_voice"],
		["b,����,download_file"],
		//["v,http://yinyueshiting.baidu.com/data2/music/42822293/42822293.mp3?xcode=eebbad91d880eee286c86b4d2d72cc37"],
		//["v,http://zhangmenshiting.baidu.com/data2/music/43099977/43099977.mp3?xcode=43797767930a4416aca186416cbdae39"],
		//["v,trust you.mp3"],
	]
	var fo = document.getElementById(parent_id)
	var lfo = document.createElement("form")
	lfo.id = "voice_form"
	fo.appendChild(lfo)
	create_table_control(lfo.id, null, text_ar)

	connect()
}
