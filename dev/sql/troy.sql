create table user (
    user_id bigint not null unique,
    user_type int   not null,
    nickname varchar(255),
    passwd_sha varchar(255),
    user_level int default 0
);

create table troy (
    troy_id bigint not null unique,
    troy_type int not null default 0,
    troy_nickname varchar(255)
);

create table group_chat (
    group_id bigint primary key auto_increment,
    owner_user_id bigint not null,
    group_nickname varchar(255) not null
);

create table group_user(
    user_id bigint not null,
    group_id bigint not null,
    operate_state int not null, # 0:本人申请，需要创建者approve 1:被别人邀请加入，需要本人approve， 2: 已经approve
    primary key(group_id, user_id)
);

create table group_troy (
    troy_id bigint not null,
    group_id bigint not null,
    primary key(group_id, troy_id)   
);

create table group_chat_msg (
    group_msg_id bigint primary key auto_increment,
    group_id bigint not null,
    msg_content varbinary(1024) not null,
    create_user_troy_id bigint not null,
    create_id_type int not null
);

insert into troy(troy_id, troy_type, troy_nickname) value(586255524153, 0, "test troy device");

create table content_classify (
    cls_id  bigint  primary key auto_increment,
    cls_name varchar(255) not null
);

create table content_subclassify (
    subcls_id  bigint  primary key auto_increment,
    cls_id     bigint not null,
    subcls_name varchar(255) not null
);

create table content (
    content_id bigint primary key auto_increment,
    cls_id bigint not null,
    subcls_id bigint not null,
    content_title varchar(255) not null,
    content_data varchar(104857600) not null
);

create table fashion_cls (
    fashion_id bigint primary key auto_increment,
    fashion_name varchar(255) not null
);

create table fashion_content (
    fashion_id bigint not null,
    content_id bigint not null,
    primary key(fashion_id, content_id)
);

create table recommend_content (
    recommend_id bigint primary key auto_increment,
    content_list varchar(1048576) not null,
    event_start_sec bigint not null,
    event_finish_sec bigint not null
);

