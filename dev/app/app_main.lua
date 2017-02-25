require "global_define"
local websocket_framework = require "websocket_framework"
local user_handler = require "user"
local group_handler = require "group"
local content_handler = require "content"
local classify_handler = require "classify"
local fashion_handler = require "fashion"
local recommend_handler = require "recommend"

function app_main()
    local peer_ctx = websocket_framework.new()
    if not peer_ctx then
        return ngx.exit(ngx.HTTP_CLOSE)
    end
    peer_ctx.user_handler_ = user_handler
    peer_ctx:register_func("user_register_cmd", user_handler.user_register)
    peer_ctx:register_func("user_forgot_cmd", user_handler.forgot_passwd)
    peer_ctx:register_func("user_login_cmd", user_handler.user_login)
    peer_ctx:register_func("user_update_cmd", user_handler.user_update)
    peer_ctx:register_func("create_group_cmd", user_handler.create_group)
    peer_ctx:register_func("get_group_cmd", user_handler.get_group)
    peer_ctx:register_func("timeout_check_task", user_handler.check_task)
    peer_ctx:register_func("invite_troy_cmd", group_handler.invite_troy)
    peer_ctx:register_func("invite_user_cmd", group_handler.invite_user)
    peer_ctx:register_func("apply_join_cmd", group_handler.apply_join)
    peer_ctx:register_func("approve_join_cmd", group_handler.approve_join)
    peer_ctx:register_func("refuse_join_cmd", group_handler.refuse_join)
    peer_ctx:register_func("dismiss_group_cmd", group_handler.dismiss_group)
    peer_ctx:register_func("send_chat_msg_cmd", group_handler.send_chat_msg)
 
    peer_ctx:register_func("create_cls_cmd", classify_handler.create_cls)
    peer_ctx:register_func("update_cls_cmd", classify_handler.update_cls)
    peer_ctx:register_func("create_subcls_cmd", classify_handler.create_subcls)
    peer_ctx:register_func("update_subcls_cmd", classify_handler.update_subcls)
 
    peer_ctx:register_func("create_content_cmd", content_handler.create_content)
    peer_ctx:register_func("get_content_cmd", content_handler.get_content)
    peer_ctx:register_func("get_cls_content_cmd", content_handler.get_cls_content)
    peer_ctx:register_func("get_subcls_content_cmd", content_handler.get_subcls_content)
    peer_ctx:register_func("remove_content_cmd", content_handler.remove_content)

    peer_ctx:register_func("create_fashion_cls_cmd", fashion_handler.create_fashion_cls)
    peer_ctx:register_func("update_fashion_cls_cmd", fashion_handler.update_fashion_cls)
    peer_ctx:register_func("create_fashion_content_cmd", fashion_handler.create_fashion_content)
    peer_ctx:register_func("delete_fashion_content_cmd", fashion_handler.delete_fashion_content)
    peer_ctx:register_func("create_recommend_cmd", recommend_handler.create_recommend)
    peer_ctx:register_func("update_recommend_cmd", recommend_handler.update_recommend)

    peer_ctx:start()
    ngx.log(ngx.INFO, peer_ctx.last_error_)
end

app_main()

