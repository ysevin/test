local server = require "resty.websocket.server"
local cjson = require "cjson"

local websocket_framework = { }
websocket_framework._VERSION = '1.0'

local websocket_framework_mt = { __index = websocket_framework }

function websocket_framework.new(self)
    local peer = { }
    setmetatable(peer, websocket_framework_mt)
    local websocket_res, websocket_err = server:new({
        timeout = 1000, -- ms
        max_payload_len = 104857600
    })
    if not websocket_res then
        ngx.log(ngx.ERR, string.format("failed to new websocket peer: %s", websocket_err))
        return
    end
    peer.websocket_peer_ = websocket_res
    peer.cmd_func_ = { }
    return peer
end

function websocket_framework.register_func(self, _cmd, _func)
    if not _cmd or not _func then return end
    self.cmd_func_[_cmd] = _func
end

function websocket_framework.start(self)
    self.last_error_ = ""
    local websocket_peer = self.websocket_peer_
	local all_data = ""
    while websocket_peer and not websocket_peer.fatal do
        -- 获取websocket 数据
        local websocket_peer_data, websocket_peer_type, websocket_peer_err = websocket_peer:recv_frame()
		--print(websocket_peer_type, string.len(websocket_peer_data or ""), websocket_peer_err)
        if not websocket_peer_data then
            local send_bytes, send_err = websocket_peer:send_ping()
            if not send_bytes then
                self.last_error_ = string.format("failed to send ping: %s", send_err)
                break
            end
            if not websocket_peer_type then
                local check_task_func = self.cmd_func_["timeout_check_task"]
                if check_task_func then check_task_func(self, nil) end
            end
        elseif websocket_peer_type == "close" then
            self.last_error_ = string.format("close websocket peer")
            break
        elseif websocket_peer_type == "ping" then
            local send_bytes, send_err = websocket_peer:send_pong()
            if not send_bytes then
                self.last_error_ = string.format("failed to send pong: %s", send_err)
                break
            end
        elseif websocket_peer_type == "pong" then
            --ngx.log(ngx.ERR, "client ponged")
        elseif websocket_peer_type == "text" or websocket_peer_type == "continuation" then
			all_data = all_data..websocket_peer_data
			if websocket_peer_err ~= "again" then
				local json_data = cjson.decode(all_data)
				all_data = ""
				if not json_data then
					self.last_error_ = string.format("cjson decode websocket_peer_data: %s", websocket_peer_data)
					break
				end
				local func_cmd = json_data.websocket_cmd
				if not func_cmd then
					self.last_error_ = string.format("not exist func_cmd websocket_peer_data: %s", websocket_peer_data)
					break
				end
				local cmd_func = self.cmd_func_[func_cmd]
				if cmd_func then
					if not cmd_func(self, json_data) then
						self.last_error_ = string.format("cmd_func run failed websocket_peer_data: %s", websocket_peer_data)
						break
					end
				else
					ngx.log(ngx.WARN, string.format("not exist cmd_func(%s) websocket_peer_data: %s", func_cmd, websocket_peer_data))
				end
			end
        else
            ngx.log(ngx.ERR, string.format("unkown websocket_peer_type: %s, websocket_peer_data: %s", websocket_peer_type, websocket_peer_data))
            break
        end
    end
end

return websocket_framework
