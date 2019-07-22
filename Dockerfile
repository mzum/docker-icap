# mzum/docker-icap
FROM ubuntu:bionic-20190612
LABEL maintainer="mzum@mzum.org"

ARG TAG
LABEL TAG=${TAG}

# WORKDIR /tmp

ENV SQUID_VERSION=3.5.27 \
    SQUID_CACHE_DIR=/var/spool/squid \
    SQUID_LOG_DIR=/var/log/squid \
    SQUID_USER=proxy

# Update ubuntu and get squid
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y squid=${SQUID_VERSION}* \
 && apt-get install traceroute curl inetutils-tools inetutils-traceroute inetutils-ping inetutils-telnet \
 && rm -rf /var/lib/apt/lists/*

# squid compile
WORKDIR /tmp
RUN apt-get update

apt-get install devscripts build-essential fakeroot libssl-dev
apt-get source squid3
sudo apt-get build-dep squid3
dpkg-source -x squid3_3.3.8-1ubuntu3.dsc
patch squid3-3.3.8/debian/rules < rules.patch
patch squid3-3.3.8/src/ssl/gadgets.cc < gadgets.cc.patch
cd squid3-3.3.8 && dpkg-buildpackage -rfakeroot -b

# Install Diladele Web Safety
wget http://updates.diladele.com/qlproxy/binaries/3.0.0.3E4A/amd64/release/ubuntu12/qlproxy-3.0.0.3E4A_amd64.deb
apt-get install python-pip
pip install django==1.5
apt-get install apache2 libapache2-mod-wsgi

# Install the DEB package and perform integration with Apache
dpkg --install qlproxy-3.0.0.3E4A_amd64.deb
a2dissite 000-default
a2ensite qlproxy
service apache2 restart

# perform squid installation 
apt-get install ssl-cert
apt-get install squid-langpack
dpkg --install squid3-common_3.3.8-1ubuntu3_all.deb
dpkg --install squid3_3.3.8-1ubuntu3_amd64.deb
dpkg --install squidclient_3.3.8-1ubuntu3_amd64.deb

# HTTPS filtering Squid / original SSL certificates
ln -s /usr/lib/squid3/ssl_crtd /bin/ssl_crtd
/bin/ssl_crtd -c -s /var/spool/squid3_ssldb
chown -R proxy:proxy /var/spool/squid3_ssldb

# integrate it with Diladele Web Safety as ICAP server
cp /etc/squid3/squid.conf /etc/squid3/squid.conf.default
patch /etc/squid3/squid.conf < squid.conf.patch
/usr/sbin/squid3 -k parse

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 3128/tcp
ENTRYPOINT ["/sbin/entrypoint.sh"]
