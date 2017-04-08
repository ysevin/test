document.write("<script src=common.js></script>") 
function toy_filter_del(id)
{
	var sd = new Array
	sd["id"] = id
	send("del_toy_filter", sd)

	toy_filter_list_del(id)

	window.event.returnValue=false;  
}

function toy_filter_update(id)
{
	var word = document.getElementById("text_word_" + id);
	var sd = new Array
	sd["id"] = id
	sd["word"] = word.value
	send("update_toy_filter", sd)

	window.event.returnValue=false;  
}

function toy_filter_add()
{
	var word = document.getElementById("text_word");

	var sd = new Array
	sd["word"] = word.value
	send("add_toy_filter", sd)

	window.event.returnValue=false;  
}

function toy_filter_search()
{
	var word = document.getElementById("search_text");
	var sd = new Array
	sd["word"] = word.value
	send("search_toy_filter", sd)

	window.event.returnValue=false;  
}

var toy_filter_list = null
function toy_filter_list_del(id)
{
	for(var idx in toy_filter_list)
	{
		var info = toy_filter_list[idx]
		if(info.id == id)
		{
			toy_filter_list.splice(idx, 1)
			break
		}
	}
	toy_filter_from_update()
}
function toy_filter_from_update()
{
	var tb_ar = new Array()
	tb_ar.push(["l,过渡词","l,操作"])
	for(var idx in toy_filter_list)
	{
		var info = toy_filter_list[idx]
		var ar = new Array()
		var i = 0
		ar[i++] = "i,text_word_"+ info.id + "," + info.word
		ar[i++] = ["b,删除,toy_filter_del(" + info.id + ")","b,更新,toy_filter_update(" + info.id + ")"]
		tb_ar.push(ar)
	}
	var di = document.getElementById("div_search")
	if(di)
		di.parentNode.removeChild(di)

	var lfo = document.getElementById("toy_filter_form")
	di = document.createElement("div")
	di.id = "div_search"
	lfo.appendChild(di)
	create_table_control(di.id, null, tb_ar)

	window.event.returnValue=false;  
}

function toy_filter_form_recv(str)
{
	var obj = JSON.parse(str);
	if(obj.toy_filter_list)
	{
		toy_filter_list = obj.toy_filter_list
		toy_filter_from_update()
	}
}
function create_toy_filter_form(parent_id)
{
	var fo = document.getElementById(parent_id)

	var lfo = document.createElement("form")
	lfo.id = "toy_filter_form"
	fo.appendChild(lfo)

	var di = document.createElement("div")
	di.id = "div1"
	lfo.appendChild(di)
	var text_ar = [
		["l,过滤词"],
		["i,text_word","b,添加,toy_filter_add()"],
	]
	create_table_control(di.id, null, text_ar)

	lfo.appendChild(document.createElement("br"))

	di = document.createElement("div")
	di.id = "div2"
	lfo.appendChild(di)
	var text_ar = [
		["i,search_text","b,搜索,toy_filter_search()"],
	]
	create_table_control(di.id, null, text_ar)
	register_recv_func("toy_filter_form", toy_filter_form_recv)

	connect()
}
