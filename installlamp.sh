#!/bin/bash

##Install AGENT LIBRENMS##
cd /opt/
git clone https://github.com/librenms/librenms-agent.git
cd librenms-agent
cp check_mk_agent /usr/bin/check_mk_agent
chmod +x /usr/bin/check_mk_agent
cp check_mk@.service check_mk.socket /etc/systemd/system
mkdir -p /usr/lib/check_mk_agent/plugins /usr/lib/check_mk_agent/local
mv /etc/systemd/system/check_mk.socket /etc/systemd/system/check_mk.socket.ori
echo > /etc/systemd/system/check_mk.socket

cat > /etc/systemd/system/check_mk.socket << EOF
[Unit]
Description=Check_MK LibreNMS Agent Socket

[Socket]
ListenStream=6556
Accept=yes
BindToDevice=eth0

[Install]
WantedBy=sockets.target
EOF

systemctl enable check_mk.socket && systemctl start check_mk.socket

##Install SNMD##

apt-get install python3-urllib3 snmpd -y
mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.old
echo > /etc/snmp/snmpd.conf

cat > /etc/snmp/snmpd.conf << EOF
master  agentx
agentAddress udp:161,udp6:[::1]:161

view   systemonly  included   .1.3.6.1.2.1.1
view   systemonly  included   .1.3.6.1.2.1.25.1

rocommunity public  localhost
rocommunity public  #iplocal

sysLocation Data Center
sysContact SysAdmin 

proc  mountd
proc  ntalkd    4
proc  sendmail 10 1

disk       /     10000
disk       /var  5%
includeAllDisks  10%

load   12 10 5
trapsink     localhost public
iquerySecName   internalUser
rouser          internalUser
defaultMonitors          yes
linkUpDownNotifications  yes

#Distro Detection
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/bin/distro
extend phpfpmsp /etc/snmp/phpfpmsp
extend apache /etc/snmp/apache-stats.py
extend mysql /etc/snmp/mysql
extend memcached /etc/snmp/memcached
EOF

#sed '18 i Debian-snmp ALL = NOPASSWD: /usr/local/bin/proxmox' /etc/sudoers
mkdir -p /var/cache/librenms/
chown -R Debian-snmp /var/cache/librenms/

sudo curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
sudo chmod +x /usr/bin/distro
wget https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/apache-stats.py -O /etc/snmp/apache-stats.py
chmod +x /etc/snmp/apache-stats.py
wget https://github.com/librenms/librenms-agent/raw/master/snmp/mysql -O /etc/snmp/mysql
chmod +x /etc/snmp/mysql
wget https://raw.githubusercontent.com/librenms/librenms-agent/master/agent-local/memcached -O /etc/snmp/memcached
chmod +x /etc/snmp/memcached
wget https://github.com/librenms/librenms-agent/raw/master/snmp/phpfpmsp -O /etc/snmp/phpfpmsp
chmod +x /etc/snmp/phpfpmsp
service snmpd restart
#service apache2 restart
##server status##

a2enmod status
cp /etc/apache2/mods-available/status.conf /etc/apache2/mods-available/status.conf.ori
echo > /etc/apache2/mods-available/status.conf
cat >  /etc/apache2/mods-available/status.conf << EOF
<IfModule mod_status.c>
        <Location /server-status>
                SetHandler server-status
                Require local
                #RewriteEngine Off
        </Location>
        ExtendedStatus On

        <IfModule mod_proxy.c>
                ProxyStatus On
        </IfModule>
</IfModule>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF
#service apache2 restart

