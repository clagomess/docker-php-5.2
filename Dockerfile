FROM debian:10-slim AS build-base

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update  \
    && apt install build-essential -y

# httpd
FROM build-base AS build-httpd
ADD ./httpd-2.2.3.tar.gz /srv
RUN cd /srv/httpd-2.2.3 \
    && ./configure --enable-so --enable-rewrite \
    && make -j4 \
    && make install
RUN cd / && tar -czvf httpd-result.tar.gz \
    /usr/local/apache2

## libxml
FROM build-base AS build-libxml
ADD ./libxml2-2.8.0.tar.xz /srv
RUN cd /srv/libxml2-2.8.0 \
    && ./configure \
    && make -j4 \
    && make install
RUN cd / && tar -czvf libxml-result.tar.gz \
    /usr/local/include/libxml2 \
    /usr/local/share/doc/libxml2-2.8.0 \
    /usr/local/share/gtk-doc/html/libxml2 \
    /usr/local/share/man/man1/xmllint.1 \
    /usr/local/share/man/man1/xml2-config.1 \
    /usr/local/share/man/man1/xmlcatalog.1 \
    /usr/local/share/man/man3/libxml.3 \
    /usr/local/share/aclocal/libxml.m4 \
    /usr/local/lib/xml2Conf.sh \
    /usr/local/lib/pkgconfig/libxml-2.0.pc \
    /usr/local/lib/libxml2.a \
    /usr/local/lib/libxml2.so.2 \
    /usr/local/lib/libxml2.so.2.8.0 \
    /usr/local/lib/libxml2.so \
    /usr/local/lib/libxml2.la \
    /usr/local/bin/xmlcatalog \
    /usr/local/bin/xml2-config \
    /usr/local/bin/xmllint

FROM build-base AS build-php

COPY --from=build-httpd /httpd-result.tar.gz /httpd-result.tar.gz
COPY --from=build-libxml /libxml-result.tar.gz /libxml-result.tar.gz
RUN cd / \
    && tar -xvf httpd-result.tar.gz \
    && tar -xvf libxml-result.tar.gz \
    && ldconfig

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt install libaio-dev -y flex libtool libpq-dev libgd-dev libcurl4-openssl-dev libmcrypt-dev -y

# oracle
ADD ./instantclient-basic-linux.x64-11.2.0.4.0.tar.gz /opt/oracle
ADD ./instantclient-sdk-linux.x64-11.2.0.4.0.tar.gz /opt/oracle
RUN echo "/opt/oracle/instantclient_11_2" > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig

# php
# ./configure --help
RUN ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/ \
&& ln -s /usr/lib/x86_64-linux-gnu/libpng.so /usr/lib/ \
&& ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl \
&& ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/ \
&& ln -s /opt/oracle/instantclient_11_2/libclntsh.so.11.1 /opt/oracle/instantclient_11_2/libclntsh.so \
&& mkdir /opt/oracle/client \
&& ln -s /opt/oracle/instantclient_11_2/sdk/include /opt/oracle/client/include \
&& ln -s /opt/oracle/instantclient_11_2 /opt/oracle/client/lib

ADD ./php-5.2.17.tar.gz /srv

RUN cd /srv/php-5.2.17 \
&& ./configure --with-apxs2=/usr/local/apache2/bin/apxs \
--with-pgsql \
--with-pdo-pgsql \
--with-gd \
--with-curl \
--enable-soap \
--with-mcrypt \
--enable-mbstring \
--enable-calendar \
--enable-bcmath \
--enable-zip \
--enable-exif \
--enable-ftp \
--enable-shmop \
--enable-sockets \
--enable-sysvmsg \
--enable-sysvsem \
--enable-sysvshm \
--enable-wddx \
--enable-dba \
#--with-openssl \ @TODO: deprec error libssl-dev; compile source
--with-gettext \
--with-mime-magic=/usr/local/apache2/conf/magic \
#--with-ldap \ @TODO: deprec error libldap2-dev; compile source
--with-oci8=instantclient,/opt/oracle/instantclient_11_2 \
--with-pdo-oci=instantclient,/opt/oracle,11.2 \
--with-ttf \
--with-png-dir=/usr \
--with-jpeg-dir=/usr \
--with-freetype-dir=/usr \
--with-zlib \
&& make -j4 \
&& make install \
&& cp php.ini-dist /usr/local/lib/php.ini

RUN cd / && tar -czvf php-result.tar.gz \
    /usr/local/lib/php \
    /usr/local/include/php \
    /usr/local/apache2/conf/httpd.conf  \
    /usr/local/apache2/conf/httpd.conf.bak \
    /usr/local/apache2/modules/libphp5.so \
    /usr/local/share/man/man1/php-config.1 \
    /usr/local/share/man/man1/php.1  \
    /usr/local/share/man/man1/phpize.1 \
    /usr/local/bin/php-config  \
    /usr/local/bin/phpize  \
    /usr/local/bin/peardev \
    /usr/local/bin/pear  \
    /usr/local/bin/pecl  \
    /usr/local/bin/php \
    /usr/local/etc/pear.conf \
    /usr/local/lib/php.ini

# php xdebug
FROM build-php AS build-xdebug
ADD ./xdebug-2.2.7.tar.gz /srv
RUN cd /srv/xdebug-2.2.7 \
    && phpize \
    && ./configure --enable-xdebug \
    && make -j4 \
    && make install
RUN cd / && tar -czvf xdebug-result.tar.gz \
    /usr/local/lib/php/extensions/no-debug-non-zts-20060613/xdebug.so

## php opcache
FROM build-php AS build-opcache
ADD ./zendopcache-7.0.5.tgz /srv
RUN cd /srv/zendopcache-7.0.5 \
    && phpize \
    && ./configure --with-php-config=php-config \
    && make \
    && make install
RUN cd / && tar -czvf opcache-result.tar.gz \
    /usr/local/lib/php/extensions/no-debug-non-zts-20060613/opcache.so

FROM debian:10-slim AS release-base

RUN mkdir /release-root

COPY --from=build-httpd /httpd-result.tar.gz /httpd-result.tar.gz
RUN tar -xvf /httpd-result.tar.gz -C /release-root

COPY --from=build-libxml /libxml-result.tar.gz /libxml-result.tar.gz
RUN tar -xvf /libxml-result.tar.gz -C /release-root

COPY --from=build-php /php-result.tar.gz /php-result.tar.gz
RUN tar -xvf /php-result.tar.gz -C /release-root

COPY --from=build-xdebug /xdebug-result.tar.gz /xdebug-result.tar.gz
RUN tar -xvf /xdebug-result.tar.gz -C /release-root

COPY --from=build-opcache /opcache-result.tar.gz /opcache-result.tar.gz
COPY ./opcache.php /release-root/srv/opcache/index.php
RUN tar -xvf /opcache-result.tar.gz -C /release-root

ADD ./soap-includes.tar.gz /release-root/usr/local/lib/php
COPY ./init.sh /release-root/srv/init.sh

ADD ./instantclient-basic-linux.x64-11.2.0.4.0.tar.gz /release-root/opt/oracle

FROM debian:10-slim AS release

LABEL org.opencontainers.image.source=https://github.com/clagomess/docker-php-5.2
LABEL org.opencontainers.image.description="Functional docker image for legacy PHP 5.2 + HTTPD + XDEBUG"

ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update \
    && apt install locales libltdl7 libaio1 libpq5 libgd3 libcurl4 libmcrypt4 -y

# add locale
RUN locale-gen pt_BR.UTF-8 \
&& echo "locales locales/locales_to_be_generated multiselect pt_BR.UTF-8 UTF-8" | debconf-set-selections \
&& rm /etc/locale.gen \
&& dpkg-reconfigure --frontend noninteractive locales

COPY --from=release-base /release-root /

# oracle
RUN echo "/opt/oracle/instantclient_11_2" > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig

# php config
RUN echo '\n\
date.timezone = America/Sao_Paulo\n\
short_open_tag=On\n\
display_errors = On\n\
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE\n\
log_errors = On\n\
error_log = /var/log/php/error.log\n\
\n\
# XDEBUG\n\
zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20060613/xdebug.so\n\
xdebug.remote_enable=${XDEBUG_REMOTE_ENABLE}\n\
xdebug.remote_handler=dbgp\n\
xdebug.remote_mode=req\n\
xdebug.remote_host=${XDEBUG_REMOTE_HOST}\n\
xdebug.remote_port=${XDEBUG_REMOTE_PORT}\n\
xdebug.remote_autostart=1\n\
xdebug.extended_info=1\n\
xdebug.remote_connect_back = 0\n\
xdebug.remote_log = /var/log/php/xdebug.log\n\
\n\
# OPCACHE\n\
zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20060613/opcache.so\n\
opcache.memory_consumption=128\n\
opcache.interned_strings_buffer=8\n\
opcache.max_accelerated_files=4000\n\
opcache.revalidate_freq=2\n\
opcache.fast_shutdown=1\n\
opcache.enable_cli=1\n\
' >> /usr/local/lib/php.ini \
&& sed -i -- "s/magic_quotes_gpc = On/magic_quotes_gpc = Off/g" /usr/local/lib/php.ini

# config httpd
RUN echo '\n\
ServerName localhost\n\
AddType application/x-httpd-php .php .phtml\n\
User www-data\n\
Group www-data\n\
Alias "/opcache" "/srv/opcache"\n\
<Directory "/srv/opcache">\n\
    Allow from all\n\
</Directory>\n\
' >> /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/ErrorLog logs\/error_log/ErrorLog \/var\/log\/apache\/error_log/g" /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/CustomLog logs\/access_log/CustomLog \/var\/log\/apache\/access_log/g" /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/AllowOverride None/AllowOverride All/g" /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/AllowOverride none/AllowOverride All/g" /usr/local/apache2/conf/httpd.conf \
&& sed -i -- "s/DirectoryIndex index.html/DirectoryIndex index.html index.php/g" /usr/local/apache2/conf/httpd.conf

# config OpenSSL
RUN sed -i -- "s/CipherString = DEFAULT@SECLEVEL=2/CipherString = DEFAULT@SECLEVEL=1/g" /usr/lib/ssl/openssl.cnf \
&& sed -i -- "s/MinProtocol = TLSv1.2/MinProtocol = TLSv1.0/g" /usr/lib/ssl/openssl.cnf

# create log files
RUN mkdir /var/log/php \
    && mkdir /var/log/apache \
    && touch /var/log/php/error.log \
    && touch /var/log/php/xdebug.log \
    && touch /var/log/apache/access_log \
    && touch /var/log/apache/error_log \
    && chown www-data:www-data /var/log/php/error.log \
    && chown www-data:www-data /var/log/php/xdebug.log \
    && chown www-data:www-data /var/log/apache/access_log \
    && chown www-data:www-data /var/log/apache/error_log

# entrypoint
CMD ["bash", "/srv/init.sh"]
