function chsize(char)
	if not char then
		return 0
	elseif char > 240 then
		return 4
	elseif char > 225 then
		return 3
	elseif char > 192 then
		return 2
	else
		return 1
	end
end

function utf8sub(str, startChar, numChars)
	local startIndex = 1
	while startChar > 1 do
		local char = string.byte(str, startIndex)
		startIndex = startIndex + chsize(char)
		startChar = startChar - 1
	end

	local currentIndex = startIndex

	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		numChars = numChars -1
	end

	return str:sub(startIndex, currentIndex - 1)
end

function utf8len(str)
	local currentIndex = 1

	local numchars = 0
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		numchars = numchars + 1
	end

	return numchars
end

function parse_table(tbl, split, extend)
	split = split.."  "

	local result = "{\n"

	for k, v in pairs(tbl) do
		local cur = split
		local lvalue_split = type(v) == "string" and "\"" or ""
		local rvalue_split = type(v) == "string" and "\"" or ""
		local flag = true
		if type(k) == "number" then
			if type(v) == "table" then
				cur = cur.."["..k.."] = "..parse_table(v, split, extend)
			elseif type(v) == "function" or type(v) == "userdata" then
				flag = false
			else
				cur = cur.."["..k.."] = "..lvalue_split..tostring(v)..rvalue_split
			end
		else
			local lkey_split = extend and "[\"" or ""
			local rkey_split = extend and "\"]" or ""
			if type(v) == "table" then
				cur = cur..lkey_split..k..rkey_split.." = "..parse_table(v, split, extend)
			elseif type(v) == "function" or type(v) == "userdata" then
				flag = false
			else
				cur = cur..lkey_split..k..rkey_split.." = "..lvalue_split..tostring(v)..rvalue_split
			end
		end
		if flag then
			result = result..cur..",\n"
		end
	end

	split = string.sub(split, 1, -3)

	result = result..split.."}"

	return result
end


function s(tbl)
	local str = ""
	if tbl == nil then
		str = "nil"
	elseif tbl == false then
		str = "false"
	else
		local tempTable = {}
		table.insert(tempTable, tbl)

		for _, v in pairs(tempTable) do
			if type(v) == "table" then
				str = parse_table(tbl, "")
			else
				str = tostring(v)
			end
		end
	end

	return str
end

function ss(o)
	print(s(o))
end

--[[
local fun=function ( ... )
	local a=1;
	print(a+1);
	return a+1;
end
--]]

tryCatch=function(fun)
	local ret,errMessage=pcall(fun);
	print("ret:" .. (ret and "true" or "false" )  .. " \nerrMessage:" .. (errMessage or "null"));
end

xTryCatchGetErrorInfo=function()
	print(debug.traceback());
end

xTryCatch=function(fun)
	local ret,errMessage=xpcall(fun,xTryCatchGetErrorInfo);
	print("ret:" .. (ret and "true" or "false" )  .. " \nerrMessage:" .. (errMessage or "null"));
end
