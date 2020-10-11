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
DROP TABLE IF EXISTS noSegments;
EOF

cat <<EOF > switch.sql
START TRANSACTION;
DROP TABLE IF EXISTS sponsorblock.categoryVotes;
DROP TABLE IF EXISTS sponsorblock.config;
DROP TABLE IF EXISTS sponsorblock.sponsorTimes;
DROP TABLE IF EXISTS sponsorblock.userNames;
DROP TABLE IF EXISTS sponsorblock.vipUsers;
DROP TABLE IF EXISTS sponsorblock.noSegments;

RENAME TABLE sponsorblock_staging.categoryVotes TO sponsorblock.categoryVotes;
RENAME TABLE sponsorblock_staging.config TO sponsorblock.config;
RENAME TABLE sponsorblock_staging.sponsorTimes TO sponsorblock.sponsorTimes;
RENAME TABLE sponsorblock_staging.userNames TO sponsorblock.userNames;
RENAME TABLE sponsorblock_staging.vipUsers TO sponsorblock.vipUsers;
RENAME TABLE sponsorblock_staging.noSegments TO sponsorblock.noSegments;
COMMIT;
EOF

curl --show-error --fail https://sponsor.ajay.app/database.db > latest.db
echo 'Downloaded database with no error'
ls -l

sqlite3 latest.db .dump | ./sqlite3-to-mysql.py | sed 's/\sTEXT/ VARCHAR(255)/g' | sed "s/\sDEFAULT\s\`sponsor\`/ DEFAULT 'sponsor'/g" | sed "s/\sdefault\s\`\`/ default ''/g" > mysql.sql
echo 'Converted to mysql'

mysql -h mysql -u sponsorblock sponsorblock_staging < clean.sql
echo 'Updated mysql database (clean)'
mysql -h mysql -u sponsorblock sponsorblock_staging < mysql.sql
echo 'Updated mysql database (mysql)'
mysql -h mysql -u sponsorblock < switch.sql
echo 'Updated mysql database (switch)'

# Upload to mirror
if test -f ~/.s3cfg; then
  echo 'Found s3 config'
  s3cmd put latest.db s3://sbmirror/staging.db
  s3cmd mv s3://sbmirror/latest.db s3://sbmirror/previous.db
  s3cmd mv s3://sbmirror/staging.db s3://sbmirror/latest.db
  s3cmd setacl --acl-public s3://sbmirror/latest.db
  s3cmd setacl --acl-public s3://sbmirror/previous.db
  echo 'Uploaded to mirror'

  mysqldump -h mysql -u sponsorblock sponsorblock > mysql_dump.sql
  s3cmd put mysql_dump.sql s3://sbmirror/mysql_dump.sqlb
  s3cmd setacl --acl-public s3://sbmirror/mysql_dump.sql
else
  echo 'No s3 config, not uploading to mirror'
fi
echo 'Job completed'
