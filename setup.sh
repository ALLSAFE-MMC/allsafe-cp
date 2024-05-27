#!/bin/sh

# Kullanıcı ve şifre ayarları
USERNAME="freebsd"
PASSWORD="123456"

# Sistem güncelleme ve gerekli paketlerin kurulumu
pkg update && pkg upgrade -y
pkg install -y python3 py37-pip isc-dhcp44-server bind916 freeradius3 git

# GitHub deposunu klonlama
cd /
git clone https://github.com/ALLSAFE-MMC/allsafe-cp.git

# Python bağımlılıklarının kurulumu
pip install flask pyrad

# DHCP yapılandırması
cat > /usr/local/etc/dhcpd.conf << EOF
subnet 192.168.40.0 netmask 255.255.255.0 {
    range 192.168.40.100 192.168.40.200;
    option routers 192.168.40.1;
    option domain-name-servers 192.168.40.1;
    default-lease-time 600;
    max-lease-time 7200;
}
EOF

sysrc dhcpd_enable="YES"
sysrc dhcpd_conf="/usr/local/etc/dhcpd.conf"
sysrc dhcpd_ifaces="wlan0"

# DNS yapılandırması
cat > /usr/local/etc/namedb/named.conf << EOF
options {
    directory "/usr/local/etc/namedb";
    allow-query { any; };
};

zone "captiveportal" IN {
    type master;
    file "captiveportal.zone";
};

zone "." IN {
    type hint;
    file "named.ca";
};
EOF

cat > /usr/local/etc/namedb/captiveportal.zone << EOF
$TTL 86400
@   IN  SOA     ns.captiveportal. admin.captiveportal. (
            1       ; Serial
            3600    ; Refresh
            1800    ; Retry
            604800  ; Expire
            86400 ) ; Minimum TTL

    IN  NS      ns.captiveportal.
ns  IN  A       192.168.40.1
*   IN  A       192.168.40.1
EOF

sysrc named_enable="YES"

# pf (Packet Filter) yapılandırması
cat > /etc/pf.conf << EOF
ext_if = "wlan0"
table <captive_portal_clients> persist

block all
pass out on $ext_if proto { tcp, udp } from any to any port 53
pass in on $ext_if proto { tcp, udp } from <captive_portal_clients> to any
pass out on $ext_if proto { tcp, udp } from any to <captive_portal_clients>
EOF

sysrc pf_enable="YES"

# RADIUS yapılandırması
cat > /usr/local/etc/raddb/clients.conf << EOF
client 192.168.40.0/24 {
    secret = shared_secret
    shortname = captiveportal
}
EOF

cat > /usr/local/etc/raddb/users << EOF
DEFAULT Auth-Type := System
    Fall-Through = 1
EOF

sysrc radiusd_enable="YES"

# Kullanıcı ekleme ve şifre ayarları
echo -e "${PASSWORD}\n${PASSWORD}" | pw useradd -n ${USERNAME} -s /bin/sh -m -h 0

# Hizmetlerin başlatılması
service isc-dhcpd start
service named start
service radiusd start
service pf start

# Captive portal uygulamasının başlatılması
cat > /etc/rc.local << EOF
#!/bin/sh
cd /allsafe-cp/backend
python3 app.py &
EOF

chmod +x /etc/rc.local

echo "Kurulum tamamlandı. Sistem yeniden başlatılıyor..."
reboot
