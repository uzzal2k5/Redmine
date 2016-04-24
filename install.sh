#!/bin/sh
# IP Address and Hostname Trace
inet_dev=`ip a | grep inet | awk -F' ' '{ print $7 }'`;
eth_ip=$(ip addr list ${inet_dev} |grep "inet " |cut -d' ' -f6|cut -d/ -f1)
ServerName=`hostname`
# SELINUX
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
# Firewall Configuration
firewall-cmd --add-service=http --permanent
firewall-cmd --reload
# Install Prerequisite one by one
# MySQL and HTTPD server Install
yum -y install mariadb-server httpd wget
#
yum -y groups install "Development Tools"
yum -y install epel-release
yum --enablerepo=epel -y install gdbm-devel libdb4-devel libffi-devel libyaml libyaml-devel ncurses-devel openssl-devel readline-devel tcl-devel
cd
mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
wget http://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.3.tar.gz -P rpmbuild/SOURCES 
wget https://raw.githubusercontent.com/tjinjin/automate-ruby-rpm/master/ruby22x.spec -P rpmbuild/SPECS
rpmbuild -bb rpmbuild/SPECS/ruby22x.spec
rpm -Uvh rpmbuild/RPMS/x86_64/ruby-2.2.3-1.el7.centos.x86_64.rpm 
ruby -v 
gem -v
yum -y install ImageMagick ImageMagick-devel libcurl-devel httpd-devel mariadb-devel ipa-pgothic-fonts
systemctl restart mariadb
systemctl enable mariadb
#db_create="
#create database redmine; 
#grant all privileges on redmine.* to redmine@'localhost' identified by 'password'; 
#flush privileges;
#\q"

db_create="
create database redmine;
\q
"
sudo mysql -u root -p -e "$db_create"
wget http://www.redmine.org/releases/redmine-3.0.3.tar.gz
tar -zxvf redmine-3.0.3.tar.gz 
mv redmine-3.0.3 /var/www/redmine
cd /var/www/redmine/config
cp database.yml.example database.yml
#sed -i "s/username: root/username: redmine/g" database.yml
#sed -i "s/password: ""/password: "password"/g" database.yml


# install bundler
cd /var/www/redmine
gem install bundler --no-rdoc --no-ri 
bundle install --without development test postgresql sqlite 
bundle exec rake generate_secret_token 
bundle exec rake db:migrate RAILS_ENV=production
gem install passenger --no-rdoc --no-ri 
passenger-install-apache2-module 

# Httpd Config

passenger="# create new VirtualHost
LoadModule passenger_module /usr/lib64/ruby/gems/2.2.0/gems/passenger-5.0.27/buildout/apache2/mod_passenger.so
   <IfModule mod_passenger.c>
     PassengerRoot /usr/lib64/ruby/gems/2.2.0/gems/passenger-5.0.27
     PassengerDefaultRuby /usr/bin/ruby
   </IfModule>
NameVirtualHost *:80
<VirtualHost *:80>
    ServerName  ${ServerName}
    DocumentRoot /var/www/redmine/public
</VirtualHost>
"
echo "$passenger">/etc/httpd/conf.d/passenger.conf
chown -R apache. /var/www/redmine 
systemctl restart httpd 
systemctl enable httpd 
systemctl status -l  httpd 
echo "Congratulation! Reboot & Browse Redmine with http://${ServerName} or http://${eth_ip}"
reboot
