FROM centos
RUN dnf install -y epel-release
RUN dnf install -y sqlite
RUN dnf install -y mysql 

COPY mysql_conv.sh mysql_conv.sh
COPY sqlite3-to-mysql.py sqlite3-to-mysql.py

ENTRYPOINT ./mysql_conv.sh
