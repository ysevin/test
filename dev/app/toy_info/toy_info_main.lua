--require "global_define"
local websocket_framework = require "toy_info/websocket_framework"
local info_handler = require "toy_info/toy_info"


function app_main()
    local peer_ctx = websocket_framework.new()
    if not peer_ctx then
        return ngx.exit(ngx.HTTP_CLOSE)
    end
    peer_ctx.user_handler_ = user_handler

    --peer_ctx:register_func("upload", person_handler.upload_info)
    --peer_ctx:register_func("query", person_handler.query_info)
    --peer_ctx:register_func("login", person_handler.login)
    
	peer_ctx:register_func("translate_voice", info_handler.translate_voice)
	peer_ctx:register_func("server_voice_send_start", info_handler.server_voice_send_start)
	peer_ctx:register_func("server_voice_send_recv", info_handler.server_voice_send_data)

    peer_ctx:register_func("voice_test", info_handler.voice_test)
    peer_ctx:register_func("toy_test", info_handler.toy_test)

    peer_ctx:register_func("hardware_voice_send_start", info_handler.hardware_voice_send_start)
    peer_ctx:register_func("hardware_voice_send_data", info_handler.hardware_voice_send_data)
    peer_ctx:register_func("hardware_voice_send_end", info_handler.hardware_voice_send_end)

    peer_ctx:register_func("upload_voice", info_handler.upload_voice)
    peer_ctx:register_func("add_toy_info", info_handler.add_toy_info)
    peer_ctx:register_func("del_toy_info", info_handler.del_toy_info)
    peer_ctx:register_func("update_toy_info", info_handler.update_toy_info)
    peer_ctx:register_func("search_toy_info", info_handler.search_toy_info)

    peer_ctx:register_func("add_toy_index", info_handler.add_toy_index)
    peer_ctx:register_func("del_toy_index", info_handler.del_toy_index)
    peer_ctx:register_func("update_toy_index", info_handler.update_toy_index)
    peer_ctx:register_func("search_toy_index", info_handler.search_toy_index)

    peer_ctx:register_func("add_toy_filter", info_handler.add_toy_filter)
    peer_ctx:register_func("del_toy_filter", info_handler.del_toy_filter)
    peer_ctx:register_func("update_toy_filter", info_handler.update_toy_filter)
    peer_ctx:register_func("search_toy_filter", info_handler.search_toy_filter)

    peer_ctx:start()
    ngx.log(ngx.INFO, peer_ctx.last_error_)
end

app_main()

