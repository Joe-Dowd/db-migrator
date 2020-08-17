#!/bin/bash
set -e

cat <<EOF > ~/.my.cnf
[client]
user=sponsorblock
password=${MYSQL_PASSWORD}
EOF

cat <<EOF > clean.sql
DROP TABLE IF EXISTS \`README:LICENSE\`;
DROP TABLE IF EXISTS categoryVotes;
DROP TABLE IF EXISTS config;
DROP TABLE IF EXISTS sponsorTimes;
DROP TABLE IF EXISTS userNames;
DROP TABLE IF EXISTS vipUsers;
EOF

cat <<EOF > switch.sql
START TRANSACTION;
DROP TABLE IF EXISTS sponsorblock.categoryVotes;
DROP TABLE IF EXISTS sponsorblock.config;
DROP TABLE IF EXISTS sponsorblock.sponsorTimes;
DROP TABLE IF EXISTS sponsorblock.userNames;
DROP TABLE IF EXISTS sponsorblock.vipUsers;

RENAME TABLE sponsorblock_staging.categoryVotes TO sponsorblock.categoryVotes;
RENAME TABLE sponsorblock_staging.config TO sponsorblock.config;
RENAME TABLE sponsorblock_staging.sponsorTimes TO sponsorblock.sponsorTimes;
RENAME TABLE sponsorblock_staging.userNames TO sponsorblock.userNames;
RENAME TABLE sponsorblock_staging.vipUsers TO sponsorblock.vipUsers;
COMMIT;
EOF

curl https://sponsor.ajay.app/database.db > latest.db 
sqlite3 latest.db .dump | ./sqlite3-to-mysql.py | sed 's/\sTEXT/ VARCHAR(255)/g' | sed "s/\sDEFAULT\s\`sponsor\`/ DEFAULT 'sponsor'/g" > mysql.sql

mysql -h mysql -u sponsorblock sponsorblock_staging < clean.sql
mysql -h mysql -u sponsorblock sponsorblock_staging < mysql.sql
mysql -h mysql -u sponsorblock < switch.sql

