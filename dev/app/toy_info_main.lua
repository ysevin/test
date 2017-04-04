require "global_define"
local websocket_framework = require "websocket_framework"
local user_handler = require "user"
local group_handler = require "group"
local content_handler = require "content"
local classify_handler = require "classify"
local fashion_handler = require "fashion"
local recommend_handler = require "recommend"
--local person_handler = require "person"
local info_handler = require "toy_info"


function app_main()
    local peer_ctx = websocket_framework.new()
    if not peer_ctx then
        return ngx.exit(ngx.HTTP_CLOSE)
    end
    peer_ctx.user_handler_ = user_handler

    --peer_ctx:register_func("upload", person_handler.upload_info)
    --peer_ctx:register_func("query", person_handler.query_info)
    --peer_ctx:register_func("login", person_handler.login)

    peer_ctx:register_func("voice_test", info_handler.voice_test)

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

