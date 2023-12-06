FROM debian:10-slim

RUN apt update \
&& apt install build-essential -y \
&& apt install vim wget locales -y

# httpd
ADD ./httpd-2.2.3.tar.gz /srv
RUN cd /srv/httpd-2.2.3 \
&& ./configure --enable-so --enable-rewrite \
&& make -j4 \
&& make install \
&& rm -rf /srv/httpd-2.2.3

# libxml
ADD ./libxml2-2.8.0.tar.xz /srv
RUN cd /srv/libxml2-2.8.0 \
&& ./configure \
&& make -j4 \
&& make install \
&& ldconfig \
&& rm -rf /srv/libxml2-2.8.0

# oracle
RUN apt install unzip libaio-dev -y && mkdir /opt/oracle
ADD ./instantclient-basic-linux.x64-11.2.0.4.0.tar.gz /opt/oracle
ADD ./instantclient-sdk-linux.x64-11.2.0.4.0.tar.gz /opt/oracle
RUN echo "/opt/oracle/instantclient_11_2" > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig

# php
# ./configure --help
RUN apt install flex libtool libpq-dev libgd-dev libcurl4-openssl-dev libmcrypt-dev -y

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
&& cp php.ini-dist /usr/local/lib/php.ini \
&& rm -rf /srv/php-5.2.17

# php config
RUN echo '\n\
date.timezone = America/Sao_Paulo\n\
short_open_tag=On\n\
display_errors = On\n\
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE\n\
log_errors = On\n\
error_log = /var/log/php/error.log\n\
' >> /usr/local/lib/php.ini \
&& sed -i -- "s/magic_quotes_gpc = On/magic_quotes_gpc = Off/g" /usr/local/lib/php.ini

# php xdebug
ADD ./xdebug-2.2.7.tar.gz /srv
RUN cd /srv/xdebug-2.2.7 \
    && phpize \
    && ./configure --enable-xdebug \
    && make -j4 \
    && make install \
    && rm -rf /srv/xdebug-2.2.7

RUN echo '\n\
zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20060613/xdebug.so\n\
xdebug.remote_enable=1\n\
xdebug.remote_handler=dbgp\n\
xdebug.remote_mode=req\n\
xdebug.remote_host=${XDEBUG_REMOTE_HOST}\n\
xdebug.remote_port=${XDEBUG_REMOTE_PORT}\n\
xdebug.remote_autostart=1\n\
xdebug.extended_info=1\n\
xdebug.remote_connect_back = 0\n\
xdebug.remote_log = /var/log/php/xdebug.log\n\
\n\' >> /usr/local/lib/php.ini

# php opcache
COPY ./opcache.php /srv/opcache/index.php
ADD ./zendopcache-7.0.5.tgz /srv
RUN cd /srv/zendopcache-7.0.5 \
    && phpize \
    && ./configure --with-php-config=php-config \
    && make \
    && make install \
    && rm -rf /srv/zendopcache-7.0.5

RUN echo '\n\
zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20060613/opcache.so\n\
opcache.memory_consumption=128\n\
opcache.interned_strings_buffer=8\n\
opcache.max_accelerated_files=4000\n\
opcache.revalidate_freq=2\n\
opcache.fast_shutdown=1\n\
opcache.enable_cli=1\n\
\n\' >> /usr/local/lib/php.ini

# php SOAP includes
ADD ./soap-includes.tar.gz /usr/local/lib/php

# config httpd
RUN echo '\n\
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

# add locale
RUN locale-gen pt_BR.UTF-8 \
&& echo "locales locales/locales_to_be_generated multiselect pt_BR.UTF-8 UTF-8" | debconf-set-selections \
&& rm /etc/locale.gen \
&& dpkg-reconfigure --frontend noninteractive locales

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
COPY ./init.sh /srv
CMD /srv/init.sh