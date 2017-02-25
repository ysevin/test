#!/bin/sh
if [ $# -ne 4 ]
then
    echo "./create_database.sh user passwd dbname sql_file"
    exit 1   
fi
mysql -u$1 -p$2 << EOF
drop database if exists $3;
create database $3;
EOF
mysql -u$1 -p$2 $3 < $4;

