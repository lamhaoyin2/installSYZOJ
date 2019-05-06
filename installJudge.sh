#!/bin/bash

# install yarn
apt update
apt install -y gnupg curl wget git software-properties-common

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mirrors.tuna.tsinghua.edu.cn/mariadb/repo/10.3/ubuntu bionic main'
add-apt-repository ppa:chris-lea/redis-server
apt update


# get sandbox
mkdir -p /opt/syzoj/sandbox/rootfs
cd /opt/syzoj/
wget https://lamfile.cf/sandbox-rootfs-181202.tar.xz
cd sandbox
tar -xJvf ../sandbox-rootfs-181202.tar.xz
mkdir -p /opt/syzoj/sandbox/{bin,tmp1}

# dependencies
apt install yarn build-essential libboost-all-dev redis-server rabbitmq-server nodejs node-gyp -y

# clone 
cd /opt/syzoj
git clone https://github.com/lamhaoyin2/judge-v3.git
mv judge-v3 judge
cd judge

# yarning
yarn
yarn run build

# configure
cd /opt/syzoj
mkdir config
cp judge/daemon-config-example.json config/daemon.json
cp judge/runner-shared-config-example.json config/runner-shared.json
cp judge/runner-instance-config-example.json config/runner-instance.json

# systemd
cd /etc/systemd/system
echo "[Unit]
Description=SYZOJ judge daemon service
After=network.target rabbitmq-server.service redis-server.service
Requires=rabbitmq-server.service redis-server.service

[Service]
Type=simple
WorkingDirectory=/opt/syzoj/judge
User=root
Group=root
ExecStart=/usr/bin/node /opt/syzoj/judge/lib/daemon/index.js -c /opt/syzoj/config/daemon.json

[Install]
WantedBy=multi-user.target" > syzA.service

echo "[Unit]
Description=SYZOJ judge runner service
After=network.target rabbitmq-server.service redis-server.service
Requires=rabbitmq-server.service redis-server.service

[Service]
Type=simple
WorkingDirectory=/opt/syzoj/judge
User=root
Group=root
ExecStart=/usr/bin/node /opt/syzoj/judge/lib/runner/index.js -s /opt/syzoj/config/runner-shared.json -i /opt/syzoj/config/runner-instance.json

[Install]
WantedBy=multi-user.target" > syzB.service

systemctl enable syzA.service
systemctl enable syzB.service

# dependencies
apt update
apt install -y mariadb-server redis-server p7zip-full python3 python3-pip clang-format
pip3 install pygments

mkdir -p /opt/syzoj
cd /opt/syzoj
git clone https://github.com/lamhaoyin2/syzoj
mv syzoj web
cd web
yarn

mkdir -p /opt/syzoj/config
cp /opt/syzoj/web/config-example.json /opt/syzoj/config/web.json
ln -s ../config/web.json /opt/syzoj/web/config.json

cd /opt/syzoj/web
mv /opt/syzoj/web/uploads /opt/syzoj/data
ln -s ../data /opt/syzoj/web/uploads
mkdir /opt/syzoj/sessions
ln -s ../sessions /opt/syzoj/web/sessions

echo "


run mysql and type:
CREATE DATABASE \`syzoj\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`syzoj\`.* TO \"syzoj\"@\"localhost\" IDENTIFIED BY \"**YOURPASSWD**\";
FLUSH PRIVILEGES;
"

cd /etc/systemd/system
echo "[Unit]
Description=SYZOJ web service
After=network.target mysql.service rc-local.service
Require=mysql.service rc-local.service

[Service]
Type=simple
WorkingDirectory=/opt/syzoj/web
User=root
Group=root
ExecStart=/usr/bin/env NODE_ENV=production /usr/bin/node /opt/syzoj/web/app.js -c /opt/syzoj/config/web.json
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > syzC.service
systemctl enable syzC.service

# install web proxy
mkdir -p /usr/local/caddy
cd /usr/local/caddy
wget https://github.com/mholt/caddy/releases/download/v1.0.0/caddy_v1.0.0_linux_amd64.tar.gz
tar -zxvf caddy_v1.0.0_linux_amd64.tar.gz
rm *.txt *.gz

# configure web server
cat -n "" > Caddyfile
echo "


Provide me your domain. 
Attention!
Your domain must have an A record to this server!

"
read -p "Enter your domain(Enter \"IP\" to use pure IP port 80): " dom
if [ "$dom" == "IP" ]; then
	dom=":80"
fi

echo "$dom {
	proxy / 127.0.0.1:5283
}" >> Caddyfile

cd /etc/systemd/system
echo "[Unit]
Description=Caddy reserve proxying

[Service]
Type=simple
WorkingDirectory=/usr/local/caddy
User=root
Group=root
ExecStart=/usr/local/caddy/caddy
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > syzD.service

systemctl enable syzD.service
