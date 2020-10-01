FROM debian:10

RUN apt update
RUN apt install build-essential -y
RUN apt install vim wget -y

# sources
RUN wget http://archive.apache.org/dist/httpd/httpd-2.2.3.tar.gz -P /srv
RUN wget http://museum.php.net/php5/php-5.2.17.tar.gz -P /srv
RUN wget ftp://xmlsoft.org/libxml2/libxml2-2.8.0.tar.gz -P /srv
RUN cd /srv && tar -xzf httpd-2.2.3.tar.gz
RUN cd /srv && tar -xzf php-5.2.17.tar.gz
RUN cd /srv && tar -xzf libxml2-2.8.0.tar.gz

# httpd
RUN cd /srv/httpd-2.2.3 \
&& ./configure --enable-so \
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
RUN apt install flex libpq-dev -y
RUN cd /srv/php-5.2.17 \
&& ./configure --with-apxs2=/usr/local/apache2/bin/apxs \
--with-pgsql \
--with-pdo-pgsql
RUN cd /srv/php-5.2.17 \
&& make -j4 \
&& make install \
&& cp php.ini-dist /usr/local/lib/php.ini

# config httpd
RUN echo "AddType application/x-httpd-php .php .phtml" >> /usr/local/apache2/conf/httpd.conf \
&& echo "User www-data" >> /usr/local/apache2/conf/httpd.conf \
&& echo "Group www-data" >> /usr/local/apache2/conf/httpd.conf

RUN ln -sf /dev/stdout /usr/local/apache2/logs/access_log \
&& ln -sf /dev/stderr /usr/local/apache2/logs/error_log