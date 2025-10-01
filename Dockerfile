FROM debian:12.12-slim AS build-base

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,id=cache-base-apt \
    --mount=type=cache,target=/var/lib/apt,id=cache-base-apt \
    apt update  \
    && apt install build-essential wget vim -y

# gmp-4.3.2
FROM build-base AS build-gmp

WORKDIR /srv/gmp-4.3.2

RUN wget --no-verbose https://ftpmirror.gnu.org/gmp/gmp-4.3.2.tar.gz \
    -O /srv/gmp-4.3.2.tar.gz
RUN tar -xf /srv/gmp-4.3.2.tar.gz -C /srv/

RUN --mount=type=cache,target=/var/cache/apt,id=cache-base-gmp \
    --mount=type=cache,target=/var/lib/apt,id=cache-base-gmp \
    apt update  \
    && apt install m4 -y

RUN ./configure --prefix /opt/gmp-4.3.2
RUN make -j$(nproc)
RUN make install

# mpfr-2.4.2
FROM build-base AS build-mpfr

WORKDIR /srv/mpfr-2.4.2

RUN wget --no-verbose https://ftpmirror.gnu.org/mpfr/mpfr-2.4.2.tar.gz \
    -O /srv/mpfr-2.4.2.tar.gz
RUN tar -xf /srv/mpfr-2.4.2.tar.gz -C /srv/

COPY --from=build-gmp /opt/gmp-4.3.2 /opt/gmp-4.3.2

RUN ./configure \
    --prefix /opt/mpfr-2.4.2 \
    --with-gmp=/opt/gmp-4.3.2
RUN make -j$(nproc)
RUN make install

# mpc-1.0.1
FROM build-base AS build-mpc

WORKDIR /srv/mpc-1.0.1

RUN wget --no-verbose https://ftpmirror.gnu.org/mpc/mpc-1.0.1.tar.gz \
    -O /srv/mpc-1.0.1.tar.gz
RUN tar -xf /srv/mpc-1.0.1.tar.gz -C /srv/

COPY --from=build-gmp /opt/gmp-4.3.2 /opt/gmp-4.3.2
COPY --from=build-mpfr /opt/mpfr-2.4.2 /opt/mpfr-2.4.2

RUN ./configure \
    --prefix /opt/mpc-1.0.1 \
    --with-gmp=/opt/gmp-4.3.2 \
    --with-mpfr=/opt/mpfr-2.4.2
RUN make -j$(nproc)
RUN make install

# gcc-8.2.0
FROM build-base AS build-gcc

WORKDIR /srv/gcc-8.2.0

RUN wget --no-verbose https://ftpmirror.gnu.org/gcc/gcc-8.2.0/gcc-8.2.0.tar.gz \
    -O /srv/gcc-8.2.0.tar.gz
RUN tar -xf /srv/gcc-8.2.0.tar.gz -C /srv/

COPY --from=build-gmp /opt/gmp-4.3.2 /opt/gmp-4.3.2
COPY --from=build-mpfr /opt/mpfr-2.4.2 /opt/mpfr-2.4.2
COPY --from=build-mpc /opt/mpc-1.0.1 /opt/mpc-1.0.1

RUN ln -s /opt/mpfr-2.4.2/lib/libmpfr.so.1 /lib/x86_64-linux-gnu/libmpfr.so.1 && \
    ln -s /opt/gmp-4.3.2/lib/libgmp.so.3 /lib/x86_64-linux-gnu/libgmp.so.3 && \
    ldconfig

# GMP 4.2+, MPFR 2.4.0+ and MPC 0.8.0+.
RUN ./configure \
    --prefix /opt/gcc-8.2.0 \
    --with-gmp=/opt/gmp-4.3.2 \
    --with-mpfr=/opt/mpfr-2.4.2 \
    --with-mpc=/opt/mpc-1.0.1 \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-libcc1 \
    --disable-libitm \
    --disable-libsanitizer \
    --disable-libquadmath \
    --disable-libvtv
RUN make -j$(nproc)
RUN make install

# httpd-2.2.3
FROM build-base AS build-httpd

WORKDIR /srv/httpd-2.2.3

RUN wget --no-verbose https://archive.apache.org/dist/httpd/httpd-2.2.3.tar.gz \
    -O /srv/httpd-2.2.3.tar.gz
RUN tar -xf /srv/httpd-2.2.3.tar.gz -C /srv/

RUN ./configure --enable-so --enable-rewrite --prefix /opt/httpd-2.2.3
RUN make -j$(nproc)
RUN make install

RUN echo 'Include conf.d/*.conf' >> /opt/httpd-2.2.3/conf/httpd.conf
COPY httpd.conf.d /opt/httpd-2.2.3/conf.d/

# libxml2-2.8.0
FROM build-base AS build-libxml2

WORKDIR /srv/libxml2-2.8.0

RUN wget --no-verbose https://download.gnome.org/sources/libxml2/2.8/libxml2-2.8.0.tar.xz \
    -O /srv/libxml2-2.8.0.tar.gz
RUN tar -xf /srv/libxml2-2.8.0.tar.gz -C /srv/

RUN ./configure --prefix /opt/libxml2-2.8.0
RUN make -j$(nproc)
RUN make install

# openssl-0.9.8h
FROM build-base AS build-openssl

WORKDIR /srv/openssl-0.9.8h

RUN wget --no-verbose https://github.com/openssl/openssl/releases/download/OpenSSL_0_9_8h/openssl-0.9.8h.tar.gz \
    -O /srv/openssl.tar.gz
RUN tar -xf /srv/openssl.tar.gz \
    --one-top-level=openssl-0.9.8h \
    --strip-components=1 \
    -C /srv/

RUN ./config \
    --prefix=/opt/openssl-0.9.8h  \
    --openssldir=/opt/openssl-0.9.8h/openssl \
    shared

RUN make
RUN make install_sw

# curl-7.19.7
FROM build-base AS build-curl

WORKDIR /srv/curl-7.19.7

RUN wget --no-verbose https://curl.se/download/archeology/curl-7.19.7.tar.gz \
    -O /srv/curl-7.19.7.tar.gz
RUN tar -xf /srv/curl-7.19.7.tar.gz -C /srv/

COPY --from=build-openssl /opt/openssl-0.9.8h /opt/openssl-0.9.8h

RUN ./configure --prefix=/opt/curl-7.19.7 \
    --with-ssl=/opt/openssl-0.9.8h \
    --disable-shared
RUN make -j$(nproc)
RUN make install

# php-5.2.17
FROM build-gcc AS build-php

WORKDIR /srv/php-5.2.17

RUN wget --no-verbose https://museum.php.net/php5/php-5.2.17.tar.gz \
    -O /srv/php-5.2.17.tar.gz
RUN tar -xf /srv/php-5.2.17.tar.gz  \
    --one-top-level=php-5.2.17 \
    --strip-components=1 \
    -C /srv/

# oracle
RUN --mount=type=cache,target=/var/cache/apt,id=cache-base-php \
    --mount=type=cache,target=/var/lib/apt,id=cache-base-php \
    apt update && \
    apt install libaio-dev -y

ADD ./instantclient-basic-linux.x64-11.2.0.4.0.tar.gz /opt/oracle
ADD ./instantclient-sdk-linux.x64-11.2.0.4.0.tar.gz /opt/oracle
RUN echo "/opt/oracle/instantclient_11_2" > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig

RUN ln -s /opt/oracle/instantclient_11_2/libclntsh.so.11.1 /opt/oracle/instantclient_11_2/libclntsh.so \
    && mkdir /opt/oracle/client \
    && ln -s /opt/oracle/instantclient_11_2/sdk/include /opt/oracle/client/include \
    && ln -s /opt/oracle/instantclient_11_2 /opt/oracle/client/lib

# jpg/png
RUN ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/ \
    && ln -s /usr/lib/x86_64-linux-gnu/libpng.so /usr/lib/

# other libs
RUN --mount=type=cache,target=/var/cache/apt,id=cache-base-php \
    --mount=type=cache,target=/var/lib/apt,id=cache-base-php \
    apt update && \
    apt install libpq-dev libgd-dev libmcrypt-dev libltdl-dev -y

COPY --from=build-httpd /opt/httpd-2.2.3 /opt/httpd-2.2.3
COPY --from=build-libxml2 /opt/libxml2-2.8.0 /opt/libxml2-2.8.0
COPY --from=build-openssl /opt/openssl-0.9.8h /opt/openssl-0.9.8h
COPY --from=build-curl /opt/curl-7.19.7 /opt/curl-7.19.7

# gcc
COPY --from=build-gcc /opt/gcc-8.2.0 /opt/gcc-8.2.0

RUN ldconfig -n /opt/gcc-8.2.0/lib/../lib64 && \
    ln -sf /opt/gcc-8.2.0/bin/gcc /usr/bin/gcc

# ./configure --help
RUN ./configure \
    --prefix=/opt/php-5.2.17 \
    --with-gnu-ld \
    --with-config-file-scan-dir=/opt/php-5.2.17/php.ini.d \
    --with-apxs2=/opt/httpd-2.2.3/bin/apxs \
    --with-libxml-dir=/opt/libxml2-2.8.0 \
    --with-pgsql \
    --with-pdo-pgsql \
    --with-gd \
    --with-curl=/opt/curl-7.19.7 \
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
    --with-openssl=/opt/openssl-0.9.8h \
    --with-gettext \
    --with-mime-magic=/opt/httpd-2.2.3/conf/magic \
    --with-oci8=instantclient,/opt/oracle/instantclient_11_2 \
    --with-pdo-oci=instantclient,/opt/oracle,11.2 \
    --with-ttf \
    --with-png-dir=/usr \
    --with-jpeg-dir=/usr \
    --with-freetype-dir=/usr \
    --with-zlib

RUN make -j$(nproc)
RUN make install
RUN cp /srv/php-5.2.17/php.ini-dist /opt/php-5.2.17/lib/php.ini
ADD ./soap-includes.tar.gz /opt/php-5.2.17/lib/php
COPY php.ini.d /opt/php-5.2.17/php.ini.d/

# php xdebug
FROM build-php AS build-xdebug

WORKDIR /srv/xdebug-2.2.7

RUN wget --no-verbose https://github.com/xdebug/xdebug/archive/refs/tags/XDEBUG_2_2_7.tar.gz \
    -O /srv/xdebug-2.2.7.tar.gz
RUN tar -xf /srv/xdebug-2.2.7.tar.gz \
    --one-top-level=xdebug-2.2.7 \
    --strip-components=1 \
    -C /srv/

COPY --from=build-php /opt/php-5.2.17 /opt/php-5.2.17

RUN /opt/php-5.2.17/bin/phpize
RUN ./configure \
    --enable-xdebug \
    --with-php-config=/opt/php-5.2.17/bin/php-config
RUN make -j$(nproc)
RUN make install

# opcache-status
FROM build-base AS build-opcache-status

RUN mkdir -p /srv/opcache
RUN wget --no-verbose https://raw.githubusercontent.com/rlerdorf/opcache-status/refs/heads/master/opcache.php \
    -O /srv/opcache/index.php

## php zendopcache-7.0.5
FROM build-php AS build-zendopcache

WORKDIR /srv/zendopcache-7.0.5

RUN wget --no-verbose https://pecl.php.net/get/zendopcache-7.0.5.tgz \
    -O /srv/zendopcache-7.0.5.tar.gz
RUN tar -xf /srv/zendopcache-7.0.5.tar.gz -C /srv/

COPY --from=build-php /opt/php-5.2.17 /opt/php-5.2.17

RUN /opt/php-5.2.17/bin/phpize

RUN ./configure \
    --with-php-config=/opt/php-5.2.17/bin/php-config
RUN make -j$(nproc)
RUN make install

# release
FROM debian:12.12-slim AS release

LABEL org.opencontainers.image.source=https://github.com/clagomess/docker-php-5.2
LABEL org.opencontainers.image.description="Functional docker image for legacy PHP 5.2 + HTTPD + XDEBUG"

WORKDIR /srv/htdocs

ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,id=cache-base-release \
    --mount=type=cache,target=/var/lib/apt,id=cache-base-release \
    apt update \
    && apt install locales libltdl7 libaio1 libnsl2 libpq5 libgd3 libmcrypt4 ssh -y

# add locale
RUN locale-gen pt_BR.UTF-8 \
&& echo "locales locales/locales_to_be_generated multiselect pt_BR.UTF-8 UTF-8" | debconf-set-selections \
&& rm /etc/locale.gen \
&& dpkg-reconfigure --frontend noninteractive locales

# ssh user
RUN useradd -m -s /bin/bash -d /srv/htdocs php && \
    echo "php:php" | chpasswd && \
    usermod -aG www-data php

# oracle
ADD ./instantclient-basic-linux.x64-11.2.0.4.0.tar.gz /opt/oracle
RUN echo "/opt/oracle/instantclient_11_2" > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig

COPY ./init.sh /opt/init.sh

# openssl
COPY --from=build-openssl /opt/openssl-0.9.8h /opt/openssl-0.9.8h
RUN echo "/opt/openssl-0.9.8h/lib" > /etc/ld.so.conf.d/openssl.conf && \
    ldconfig

# curl
COPY --from=build-curl /opt/curl-7.19.7 /opt/curl-7.19.7
RUN ln -s /opt/curl-7.19.7/bin/curl /usr/bin/curl

# libxml
COPY --from=build-libxml2 /opt/libxml2-2.8.0 /opt/libxml2-2.8.0
RUN echo "/opt/libxml2-2.8.0/lib" > /etc/ld.so.conf.d/libxml2.conf && \
    ldconfig

COPY --from=build-opcache-status /srv/opcache /srv/opcache

# php
COPY --from=build-php /opt/php-5.2.17 /opt/php-5.2.17
RUN ln -s /opt/php-5.2.17/bin/php /usr/bin/php

COPY --from=build-zendopcache /opt/php-5.2.17/lib/php/extensions/no-debug-non-zts-20060613/opcache.so /opt/php-5.2.17/lib/php/extensions/no-debug-non-zts-20060613/opcache.so
COPY --from=build-php /opt/httpd-2.2.3 /opt/httpd-2.2.3
COPY --from=build-xdebug /opt/php-5.2.17/lib/php/extensions/no-debug-non-zts-20060613/xdebug.so /opt/php-5.2.17/lib/php/extensions/no-debug-non-zts-20060613/xdebug.so

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
CMD ["bash", "/opt/init.sh"]
