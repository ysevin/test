document.write("<script src=toy_info/common.js></script>") 

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
		toy_test(file_id)
	}
}

function toy_test_form_recv(str)
{
	var obj = JSON.parse(str);
	var ar = [
		["v,,"+obj.voice_url],
	]
	create_text_control("toy_test_form", ar)

	//window.event.returnValue=false;  
	//return
}

function toy_test(file_id)
{
	var sd = new Array
	sd["file_ext"] = voice_file[file_id]["voice_ext"]
	sd["file_len"] = voice_file[file_id]["voice_len"]
	sd["file_name"] = voice_file[file_id]["voice_name"]
	sd["file_content"] = voice_file[file_id]["voice_content"]
	sd["file_rate"] = voice_file[file_id]["voice_rate"]
	send("voice_test", sd)

	window.event.returnValue=false;  
}

function create_toy_test_form(parent_id)
{
	var text_ar = [
		["a,过滤库,toy_info/toy_filter.html"],
		["a,索引库,toy_info/toy_index.html"],
		["a,信息库,toy_info/toy_info.html"],
	]
	var fo = document.getElementById(parent_id)
	var lfo = document.createElement("form")
	lfo.id = "toy_test_form"
	fo.appendChild(lfo)
	create_table_control(lfo.id, null, text_ar)

	register_recv_func("toy_test_form", toy_test_form_recv)

	connect()
}
