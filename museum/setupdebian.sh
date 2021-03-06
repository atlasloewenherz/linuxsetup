#!/bin/bash


export MYHOST=`echo $(hostname)`
echo "Please enter a MySQL root password: "
read MYSQLROOTPASSWORD
echo "Please enter the hostname for munin: "
read MYMUNININSTANCE

# sort the apt sources out properly
echo ## The golem appended the following sources >> /etc/apt/sources.list
echo deb http://ftp.de.debian.org/debian squeeze main >> /etc/apt/sources.list
echo deb-src http://ftp.de.debian.org/debian squeeze main >> /etc/apt/sources.list
echo deb http://nginx.org/packages/debian/ squeeze nginx >> /etc/apt/sources.list
echo deb-src http://nginx.org/packages/debian/ squeeze nginx >> /etc/apt/sources.list
echo deb http://packages.dotdeb.org stable all >> /etc/apt/sources.list
wget http://www.dotdeb.org/dotdeb.gpg
cat dotdeb.gpg | apt-key add -
rm dotdeb.gpg
wget http://nginx.org/keys/nginx_signing.key
cat nginx_signing.key | apt-key add -
rm nginx_signing.key

# get the deb stuff updated
apt-get update

# let's tell MySQL its password to avoid asking
echo mysql-server-5.1 mysql-server/root_password password $MYSQLROOTPASSWORD | debconf-set-selections
echo mysql-server-5.1 mysql-server/root_password_again password $MYSQLROOTPASSWORD | debconf-set-selections

# some essential software is installed
apt-get -y install locales vim php5 php5-fpm php-pear php5-common php5-mcrypt php5-mysql php5-cli php5-gd nginx imagemagick locate mysql-server mysql-client munin munin-node munin-plugins-extra libio-all-lwp-perl telnet python git-core g++ openssl libssl-dev make

# tune up php-fpm
echo pm.max_children = 25 >> /etc/php5/fpm/php-fpm.conf
echo pm.start_servers = 4 >> /etc/php5/fpm/php-fpm.conf
echo pm.min_spare_servers = 2 >> /etc/php5/fpm/php-fpm.conf
echo pm.max_spare_servers = 10 >> /etc/php5/fpm/php-fpm.conf
echo pm.max_requests = 500 >> /etc/php5/fpm/php-fpm.conf
echo request_terminate_timeout = 90s >> /etc/php5/fpm/php-fpm.conf

# set up fastcgi params
echo "fastcgi_connect_timeout 60;" >> /etc/nginx/conf.d/fastcgi_params
echo "fastcgi_send_timeout 180;" >> /etc/nginx/conf.d/fastcgi_params
echo "fastcgi_read_timeout 180;" >> /etc/nginx/conf.d/fastcgi_params
echo "fastcgi_buffer_size 128k;" >> /etc/nginx/conf.d/fastcgi_params
echo "fastcgi_buffers 4 256k;" >> /etc/nginx/conf.d/fastcgi_params
echo "fastcgi_busy_buffers_size 256k;" >> /etc/nginx/conf.d/fastcgi_params
echo "fastcgi_temp_file_write_size 256k;" >> /etc/nginx/conf.d/fastcgi_params
echo "fastcgi_intercept_errors on;" >> /etc/nginx/conf.d/fastcgi_params

# adjust /etc/nginx/nginx.conf
# append in http section
#sed -e 's/include \/etc\/nginx\/conf.d\/*.conf;/client_max_body_size 20M;\nclient_body_buffer_size 128k;\ninclude \/etc\/nginx\/conf.d\/*.conf;/' > /etc/nginx/nginx.conf
#client_max_body_size 20M;
#client_body_buffer_size 128k;

# set up sites for nginx
echo "server {
  listen 8080 ;  #could also be 1.2.3.4:80

  server_name $MYHOST; # Alternately: _
  root /var/www/html;

  index index.php index.html index.htm;

   try_files $uri $uri/ /index.php?$args;

  # serve static files directly
  location ~* \.(js|ico|gif|jpg|jpeg|png|css|html|htm|swf|htc|xml|bmp|cur|txt)$ {
     access_log off;
     expires max;
  }

  location ~ \.php$ {
      # Security: must set cgi.fix_pathinfo to 0 in php.ini!
      fastcgi_split_path_info ^(.+\.php)(/.+)$;
      fastcgi_pass 127.0.0.1:9000;
      fastcgi_index index.php;
      fastcgi_param SCRIPT_FILENAME         $document_root$fastcgi_script_name;
      fastcgi_param PATH_INFO $fastcgi_path_info;
      include /etc/nginx/fastcgi_params;
  }

  location ~ /\.ht {
    deny all;
  }
}" > /etc/nginx/conf.d/sample_conf

# configure php
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=1/g' /etc/php5/fpm/php.ini 


# munin will be served via nginx
touch /etc/nginx/conf.d/munin.conf
echo "server {
  server_name $MYMUNININSTANCE;
  root /var/cache/munin/www/;
  # Restrict Munin access
  #auth_basic "Restricted";
  #auth_basic_user_file /etc/nginx/htpasswd;
  location / {
    index index.html;
    access_log off;
  }
}
 server {
       listen 127.0.0.1;
       server_name localhost;
       location /nginx_status {
               stub_status on;
               access_log   off;
               allow 127.0.0.1;
               deny all;
       }
}" > /etc/nginx/conf.d/munin.conf
mkdir -p /var/www/html
rm /etc/nginx/conf.d/default.conf


# enable munin plugins
wget --no-check-certificate https://github.com/munin-monitoring/contrib/raw/master/plugins/mysql/mysql_size_all --output-document=/usr/share/munin/plugins/mysql_size_all
wget --no-check-certificate #https://github.com/munin-monitoring/contrib/raw/master/plugins/nginx/php5-fpm_status --output-document=/usr/share/munin/plugins/php5-fpm_status
wget --no-check-certificate https://github.com/munin-monitoring/contrib/raw/master/plugins/nginx/nginx_memory --output-document=/usr/share/munin/plugins/nginx_memory
ln -s /usr/share/munin/plugins/df_abs  /etc/munin/plugins/
ln -s /usr/share/munin/plugins/mysql_bytes       /etc/munin/plugins/
ln -s /usr/share/munin/plugins/mysql_queries     /etc/munin/plugins/
ln -s /usr/share/munin/plugins/mysql_size_all /etc/munin/plugins/
ln -s /usr/share/munin/plugins/mysql_slowqueries /etc/munin/plugins/
ln -s /usr/share/munin/plugins/mysql_threads     /etc/munin/plugins/
ln -s /usr/share/munin/plugins/netstat /etc/munin/plugins/
ln -s /usr/share/munin/plugins/nginx_memory  /etc/munin/plugins/
ln -s /usr/share/munin/plugins/nginx_request /etc/munin/plugins/
ln -s /usr/share/munin/plugins/nginx_status  /etc/munin/plugins/
#ln -s /usr/share/munin/plugins/php5-fpm_status /etc/munin/plugins/
ln -s /usr/share/munin/plugins/ping_  /etc/munin/plugins/ping_google.com

# let's configure the munin plugins a bit
echo "[nginx*]
env.url http://localhost/nginx_status
env.ua nginx-status-verifier/0.1
" > /etc/munin/plugin-conf.d/nginx
echo "[netstat]
user root
" > /etc/munin/plugin-conf.d/netstat
sed -i "s/\[localhost\.localdomain\]/[$MYMUNININSTANCE]/g" /etc/munin/munin.conf
chmod -R 755 /usr/share/munin/plugins/

# restart services
update-rc.d cron defaults
/etc/init.d/cron restart
/etc/init.d/nginx restart
/etc/init.d/munin-node restart
/etc/init.d/mysql restart
/etc/init.d/php5-fpm restart

# set up gmail
# http://kevin.deldycke.com/2011/05/how-to-gmail-send-mails-debian-squeeze/

# set up hugin and munin and integrate with nginx