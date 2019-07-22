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

# sources.list
RUN cp -p /etc/apt/sources.list /etc/apt/sources.list~
RUN ls -l /etc/apt/
RUN sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
RUN apt-get update

# Update ubuntu and get squid
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y squid=${SQUID_VERSION}*

RUN apt-get update \ 
 && apt-get -y install traceroute curl inetutils-tools inetutils-traceroute inetutils-ping inetutils-telnet ca-certificates libcurl4 libidn11 libnghttp2-14 libpsl5 librtmp1 libshishi0
 
# squid compile
WORKDIR /tmp
RUN apt-get update

RUN apt-get install -y devscripts build-essential fakeroot libssl-dev
RUN apt-get source -y squid3
RUN apt-get build-dep -y squid3
RUN dpkg-source -x squid3_3.3.8-1ubuntu3.dsc
RUN patch squid3-3.3.8/debian/rules < rules.patch
RUN patch squid3-3.3.8/src/ssl/gadgets.cc < gadgets.cc.patch
RUN cd squid3-3.3.8 && dpkg-buildpackage -rfakeroot -b
RUN apt-get update

# Install Diladele Web Safety
RUN wget http://updates.diladele.com/qlproxy/binaries/3.0.0.3E4A/amd64/release/ubuntu12/qlproxy-3.0.0.3E4A_amd64.deb
RUN apt-get install -y python-pip
RUN pip install django==1.5
RUN apt-get -y install apache2 libapache2-mod-wsgi
RUN apt-get update

# Install the DEB package and perform integration with Apache
RUN dpkg --install qlproxy-3.0.0.3E4A_amd64.deb
RUN a2dissite 000-default
RUN a2ensite qlproxy
RUN service apache2 restart

# perform squid installation 
RUN apt-get install -y ssl-cert
RUN apt-get install -y squid-langpack
RUN dpkg --install squid3-common_3.3.8-1ubuntu3_all.deb
RUN dpkg --install squid3_3.3.8-1ubuntu3_amd64.deb
RUN dpkg --install squidclient_3.3.8-1ubuntu3_amd64.deb
RUN apt-get update
RUN apt-get upgrade

# HTTPS filtering Squid / original SSL certificates
RUN ln -s /usr/lib/squid3/ssl_crtd /bin/ssl_crtd
RUN /bin/ssl_crtd -c -s /var/spool/squid3_ssldb
RUN chown -R proxy:proxy /var/spool/squid3_ssldb

# integrate it with Diladele Web Safety as ICAP server
RUN cp /etc/squid3/squid.conf /etc/squid3/squid.conf.default
RUN patch /etc/squid3/squid.conf < squid.conf.patch
RUN /usr/sbin/squid3 -k parse

RUN rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 3128/tcp
ENTRYPOINT ["/sbin/entrypoint.sh"]
