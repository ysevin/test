document.write("<script src=common.js></script>") 
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

function create_voice_translate_form(parent_id)
{
	var text_ar = [
		["b,ÉÏ´«,translate_voice('translate_voice_file')"],
		["vf,translate_voice_file"],
	]
	var fo = document.getElementById(parent_id)
	var lfo = document.createElement("form")
	lfo.id = "voice_translate_form"
	fo.appendChild(lfo)
	create_table_control(lfo.id, null, text_ar)

	connect()
}
