document.write("<script src=common.js></script>") 
function toy_index_del(id)
{
	var sd = new Array
	sd["id"] = id
	send_data("del_toy_index", sd)

	toy_index_list_del(id)

	window.event.returnValue=false;  
}

function toy_index_update(id)
{
	var word = document.getElementById("text_word_" + id);
	var key_word = document.getElementById("text_key_word_" + id);
	var weight = document.getElementById("text_weight_" + id);
	var sd = new Array
	sd["id"] = id
	sd["word"] = word.value
	sd["key_word"] = key_word.value
	sd["weight"] = weight.value
	send_data("update_toy_index", sd)

	window.event.returnValue=false;  
}

function toy_index_add()
{
	var word = document.getElementById("text_word");
	var key_word = document.getElementById("text_key_word");
	var weight = document.getElementById("text_weight");

	var sd = new Array
	sd["word"] = word.value
	sd["key_word"] = key_word.value
	sd["weight"] = weight.value
	send_data("add_toy_index", sd)

	window.event.returnValue=false;  
}

function toy_index_search()
{
	var word = document.getElementById("search_text");
	var sd = new Array
	sd["word"] = word.value
	send_data("search_toy_index", sd)

	window.event.returnValue=false;  
}

var toy_index_list = null

function toy_index_list_del(id)
{
	for(var idx in toy_index_list)
	{
		var info = toy_index_list[idx]
		if(info.id == id)
		{
			toy_index_list.splice(idx, 1)
			break
		}
	}
	toy_index_from_update()
}
function toy_index_from_update()
{
	var filter = document.getElementById("filter_text")
	var num = parseInt(filter.value)
	if(!num) num = 0
	var checkbox = document.getElementById("filter_checkbox")
	if(!checkbox.checked)
		num = 0
	
	var tb_ar = new Array()
	tb_ar.push(["l,用户词","l,关键词","l,权重","l,搜索次数","l,操作"])
	for(var idx in toy_index_list)
	{
		var info = toy_index_list[idx]
		if(info.weight >= num)
		{
			var ar = new Array()
			var i = 0
			ar[i++] = "i,text_word_"+ info.id + "," + info.word
			ar[i++] = "i,text_key_word_"+ info.id + "," + info.key_word
			ar[i++] = "i,text_weight_"+ info.id + "," + info.weight
			ar[i++] = "l," + info.search_num
			ar[i++] = ["b,删除,toy_index_del(" + info.id + ")","b,更新,toy_index_update(" + info.id + ")"]
			tb_ar.push(ar)
		}
	}
	var di = document.getElementById("div_search")
	if(di)
		di.parentNode.removeChild(di)

	var lfo = document.getElementById("toy_index_form")
	di = document.createElement("div")
	di.id = "div_search"
	lfo.appendChild(di)
	create_table_control(di.id, null, tb_ar)

	window.event.returnValue=false;  
}

function toy_index_form_recv(str)
{
	var obj = JSON.parse(str);
	if(obj.toy_index_list)
	{
		toy_index_list = obj.toy_index_list
		toy_index_from_update()
	}
}
function create_toy_index_form(parent_id)
{
	var fo = document.getElementById(parent_id)

	var lfo = document.createElement("form")
	lfo.id = "toy_index_form"
	fo.appendChild(lfo)

	var di = document.createElement("div")
	di.id = "div1"
	lfo.appendChild(di)
	var text_ar = [
		["l,用户词","l,关键词","l,权重"],
		["i,text_word","i,text_key_word","i,text_weight","b,添加,toy_index_add()"],
	]
	create_table_control(di.id, null, text_ar)

	lfo.appendChild(document.createElement("br"))

	di = document.createElement("div")
	di.id = "div2"
	lfo.appendChild(di)
	var text_ar = [
		["i,search_text","b,搜索,toy_index_search()",["c,filter_checkbox", "i,filter_text"]],
	]
	create_table_control(di.id, null, text_ar)
	var ip = document.getElementById("filter_text")
	ip.placeholder = "过滤搜索次数大于"

	connect()
}
