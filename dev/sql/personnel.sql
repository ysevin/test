create table persons (
    id bigint primary key auto_increment,
    nationality varchar(255) default "",
    area varchar(255) default "",
    birthday date not null,
    gender varchar(255) not null, 
    entry date not null, 
	company varchar(255) default "",
	address varchar(255) default "",
	phone bigint not null,
	fingerprint MediumBlob,
	photo MediumBlob,
	remark varchar(255) default ""
);

insert into persons(nationality, area, birthday, gender, entry, company, address, phone, fingerprint, photo, remark) value("非洲", "刚果", "1990-01-01", "男", "2010-01-01", "网易", "天河", 1380000000, null, null, "123");
