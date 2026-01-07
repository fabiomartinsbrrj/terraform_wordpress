#!/bin/bash
# Buscar credenciais e endpoint do SSM Parameter Store
db_username=$(aws ssm get-parameter --name "${ssm_db_username_parameter}" --region ${aws_region} --query 'Parameter.Value' --output text)
db_user_password=$(aws ssm get-parameter --name "${ssm_db_password_parameter}" --region ${aws_region} --with-decryption --query 'Parameter.Value' --output text)
db_endpoint=$(aws ssm get-parameter --name "${ssm_db_endpoint_parameter}" --region ${aws_region} --query 'Parameter.Value' --output text)
db_name=${db_name}
yum update -y
yum install -y httpd
yum install -y mysql
amazon-linux-extras enable php7.4
yum clean metadata
yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap,devel}
#install imagick extension
yum -y install gcc ImageMagick ImageMagick-devel ImageMagick-perl
pecl install imagick
chmod 755 /usr/lib64/php/modules/imagick.so
cat <<EOF >>/etc/php.d/20-imagick.ini

extension=imagick

EOF

systemctl restart php-fpm.service

systemctl start  httpd

usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;



curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
wp core download --path=/var/www/html --allow-root
wp config create --dbname=$db_name --dbuser=$db_username --dbpass=$db_user_password --dbhost=$db_endpoint --path=/var/www/html --allow-root --extra-php <<PHP
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
PHP

chown -R ec2-user:apache /var/www/html
chmod -R 774 /var/www/html

sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf
systemctl enable  httpd.service
systemctl restart httpd.service
echo WordPress Installed