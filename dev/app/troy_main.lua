require "global_define"
local websocket_framework = require "websocket_framework"
local troy_handler = require "troy"

function troy_main()
    math.randomseed(os.time())
    local peer_ctx = websocket_framework.new()
    if not peer_ctx then
        return ngx.exit(ngx.HTTP_CLOSE)
    end
    peer_ctx.troy_handler_ = troy_handler
    peer_ctx:register_func("timeout_check_task", troy_handler.check_task)
    peer_ctx:register_func("troy_connect_cmd", troy_handler.connect_server)
    peer_ctx:register_func("troy_invite_code_cmd", troy_handler.generate_invite_code)
    peer_ctx:register_func("troy_send_chat_msg_cmd", troy_handler.send_chat_msg)
    peer_ctx:start()
    ngx.log(ngx.INFO, peer_ctx.last_error_)
end

troy_main()







