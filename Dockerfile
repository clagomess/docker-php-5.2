FROM debian:10

RUN apt update \
&& apt install build-essential -y \
&& apt install vim wget locales -y

# sources
RUN wget http://archive.apache.org/dist/httpd/httpd-2.2.3.tar.gz -P /srv
RUN wget http://museum.php.net/php5/php-5.2.17.tar.gz -P /srv
RUN wget ftp://xmlsoft.org/libxml2/libxml2-2.8.0.tar.gz -P /srv
RUN cd /srv && tar -xzf httpd-2.2.3.tar.gz
RUN cd /srv && tar -xzf php-5.2.17.tar.gz
RUN cd /srv && tar -xzf libxml2-2.8.0.tar.gz

# oracle
RUN apt install unzip libaio-dev -y && mkdir /opt/oracle
RUN wget http://cloud.gomespro.com.br/instant-client-11/instantclient-basic-linux.x64-11.2.0.4.0.zip -P /opt/oracle
RUN wget http://cloud.gomespro.com.br/instant-client-11/instantclient-sdk-linux.x64-11.2.0.4.0.zip -P /opt/oracle
RUN unzip /opt/oracle/instantclient-basic-linux.x64-11.2.0.4.0.zip -d /opt/oracle
RUN unzip /opt/oracle/instantclient-sdk-linux.x64-11.2.0.4.0.zip -d /opt/oracle
RUN echo "/opt/oracle/instantclient_11_2" > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig

# httpd
RUN cd /srv/httpd-2.2.3 \
&& ./configure --enable-so --enable-rewrite \
&& make -j4 \
&& make install

# libxml
RUN cd /srv/libxml2-2.8.0 \
&& ./configure \
&& make -j4 \
&& make install \
&& ldconfig

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
--with-mime-magic \
#--with-ldap \ @TODO: deprec error libldap2-dev; compile source
--with-oci8=instantclient,/opt/oracle/instantclient_11_2 \
--with-pdo-oci=instantclient,/opt/oracle,11.2 \
--with-ttf \
--with-png-dir=/usr \
--with-jpeg-dir=/usr \
--with-freetype-dir=/usr \
--with-zlib

RUN cd /srv/php-5.2.17 \
&& make -j4 \
&& make install \
&& cp php.ini-dist /usr/local/lib/php.ini

# php xdebug
RUN pecl channel-update pecl.php.net
RUN pecl install xdebug-2.2.7
RUN pecl install zendopcache-7.0.5
RUN echo '\n\
zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20060613/opcache.so\n\
opcache.memory_consumption=128\n\
opcache.interned_strings_buffer=8\n\
opcache.max_accelerated_files=4000\n\
opcache.revalidate_freq=60\n\
opcache.fast_shutdown=1\n\
opcache.enable_cli=1\n\
\n\
zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20060613/xdebug.so\n\
xdebug.remote_enable=1\n\
xdebug.remote_handler=dbgp\n\
xdebug.remote_mode=req\n\
xdebug.remote_host=host.docker.internal\n\
xdebug.remote_port=9000\n\
xdebug.remote_autostart=1\n\
xdebug.extended_info=1\n\
xdebug.remote_connect_back = 0\n\
\n\
date.timezone = America/Sao_Paulo\n\
short_open_tag=On\n\
display_errors = On\n\
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE\n\
log_errors = On\n\
error_log = /usr/local/apache2/logs/error_log\n\
' >> /usr/local/lib/php.ini \
&& sed -i -- "s/magic_quotes_gpc = On/magic_quotes_gpc = Off/g" /usr/local/lib/php.ini

# config httpd
RUN echo "AddType application/x-httpd-php .php .phtml" >> /usr/local/apache2/conf/httpd.conf \
&& echo "User www-data" >> /usr/local/apache2/conf/httpd.conf \
&& echo "Group www-data" >> /usr/local/apache2/conf/httpd.conf \
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

# config stdlog
RUN ln -sf /dev/stdout /usr/local/apache2/logs/access_log \
&& ln -sf /dev/stderr /usr/local/apache2/logs/error_log
