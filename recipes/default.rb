#
# Cookbook:: Ubuntu_web
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

execute "update-upgrade" do
  command "apt-get update -y"
  action :run
end

package "apache2" do
  action :install
end

package "ufw" do 
  action :install
end

service "apache2" do
  action [:enable, :start]
end

service "ufw" do
  action [:enable, :start]
end

execute "ufw port" do
  command "ufw allow 22 && ufw allow 80 && ufw allow 443"
  action :run
end

execute "enable ssl rewrite" do
  command "a2enmod ssl && a2enmod rewrite"
end

execute "create key ssl" do
  command "mkdir /etc/apache2/ssl && openssl genrsa -out /etc/apache2/ssl/ca.key 2048"
  not_if {Dir.exist?('/etc/apache2/ssl')}
end

execute "create csr file" do
  command "openssl req -nodes -new -key /etc/apache2/ssl/ca.key -out /etc/apache2/ssl/ca.csr -subj '/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com'"
  only_if { File.exist?('/etc/apache2/ssl/ca.key') }
end

execute "creata crt file" do
  command "openssl x509 -req -days 365 -in /etc/apache2/ssl/ca.csr -signkey /etc/apache2/ssl/ca.key -out /etc/apache2/ssl/ca.crt"
  only_if {  File.exist?('/etc/apache2/ssl/ca.csr') }
end

file "/var/www/html/index.html" do
  content "
<html>SRE CHALLENGE
</html>"
  owner "root"
  group "root"
  mode "0755"
end

execute "curl" do
  command "curl -k https://localhost "
  action :nothing
end

execute "test" do
  command "sudo netstat -lntp | grep ':443.*apache2' > /dev/null && echo 'Apache server is listening to Port 443'"
  action :nothing
end

file "/etc/apache2/sites-available/000-default.conf"  do
  content "
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        RewriteEngine On
        RewriteCond %{HTTPS} !=on
        RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>

NameVirtualHost *:443
<VirtualHost *:443>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/ca.crt
        SSLCertificateKeyFile /etc/apache2/ssl/ca.key
</VirtualHost>
"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, "service[apache2]"
  notifies :run, "execute[curl]"
  notifies :run, "execute[test]"
end

describe port 443 do
  it { should be_listening }
end
