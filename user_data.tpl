#!/bin/bash
# Buscar credenciais e endpoint do SSM Parameter Store
db_username=$(aws ssm get-parameter --name "${ssm_db_username_parameter}" --region ${aws_region} --query 'Parameter.Value' --output text)
db_user_password=$(aws ssm get-parameter --name "${ssm_db_password_parameter}" --region ${aws_region} --with-decryption --query 'Parameter.Value' --output text)
db_endpoint=$(aws ssm get-parameter --name "${ssm_db_endpoint_parameter}" --region ${aws_region} --query 'Parameter.Value' --output text)
db_name=${db_name}

# Atualizar sistema e instalar pacotes básicos
yum update -y
yum install -y httpd mysql amazon-efs-utils
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

# ==============================================================================
# CONFIGURAÇÃO EFS - Compartilhamento de arquivos WordPress
# ==============================================================================

# Criar diretório temporário para backup do WordPress local
mkdir -p /tmp/wordpress-backup

# Fazer backup do WordPress instalado localmente (se existir conteúdo)
if [ -d "/var/www/html" ] && [ "$(ls -A /var/www/html)" ]; then
    cp -r /var/www/html/* /tmp/wordpress-backup/
fi

# Montar EFS no diretório WordPress usando access point
# - TLS para criptografia em trânsito
# - Access point garante permissões corretas (www-data)
mount -t efs -o tls,accesspoint=${efs_access_point_id} ${efs_dns_name}:/ /var/www/html

# Verificar se o mount foi bem-sucedido
if mountpoint -q /var/www/html; then
    echo "EFS montado com sucesso em /var/www/html"
    
    # Se EFS está vazio e temos backup local, restaurar
    if [ ! "$(ls -A /var/www/html)" ] && [ -d "/tmp/wordpress-backup" ] && [ "$(ls -A /tmp/wordpress-backup)" ]; then
        echo "Restaurando WordPress do backup local para EFS..."
        cp -r /tmp/wordpress-backup/* /var/www/html/
    fi
else
    echo "ERRO: Falha ao montar EFS. Usando storage local."
fi

# Configurar mount permanente no /etc/fstab para reinicializações
echo "${efs_dns_name}:/ /var/www/html efs defaults,_netdev,tls,accesspoint=${efs_access_point_id} 0 0" >> /etc/fstab

# Criar diretório para sessões compartilhadas no EFS
mkdir -p /var/www/html/wp-content/sessions
chown -R apache:apache /var/www/html/wp-content/sessions
chmod -R 755 /var/www/html/wp-content/sessions

# Configurar PHP para usar sessões compartilhadas
echo "session.save_path = \"/var/www/html/wp-content/sessions\"" >> /etc/php.d/99-sessions.ini

# Ajustar permissões para www-data (Apache)
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Configurar Apache e iniciar serviços
sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf
systemctl enable httpd.service
systemctl restart httpd.service

# Reiniciar PHP-FPM para aplicar configurações de sessão
systemctl restart php-fpm.service

# Limpar backup temporário
rm -rf /tmp/wordpress-backup
echo WordPress Installed