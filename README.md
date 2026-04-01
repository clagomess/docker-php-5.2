# docker-php-5.2

DON'T USE IN PRODUCTION!

## Download
- Github: `docker pull ghcr.io/clagomess/docker-php-5.2:latest`
- DockerHub: `docker pull clagomess/docker-php-5.2:latest`

## Use
- DocumentRoot: `/srv/htdocs/`
- Custom PHP Config: `/opt/php-5.2.17/php.ini.d/`
- Custom Apache HTTPD Config: `/opt/httpd-2.2.3/conf.d/`
- OpCache Panel: `http://localhost:8000/opcache/`
- SSH user & pass: php

Example:
```bash
docker run --rm \
  -p 8000:80 \
  -p 2200:22 \
  -e XDEBUG_REMOTE_ENABLE=1 \
  -e XDEBUG_REMOTE_HOST=host.docker.internal \
  -e XDEBUG_REMOTE_PORT=9000 \
  -v .:/srv/htdocs \
  ghcr.io/clagomess/docker-php-5.2 
```

## Build
```bash
docker build -t ghcr.io/clagomess/docker-php-5.2:gcc -f Dockerfile-040-gcc .
docker build -t ghcr.io/clagomess/docker-php-5.2:httpd -f Dockerfile-050-httpd .
docker build -t ghcr.io/clagomess/docker-php-5.2:libxml2 -f Dockerfile-060-libxml2 .
docker build -t ghcr.io/clagomess/docker-php-5.2:openssl -f Dockerfile-070-openssl .
docker build -t ghcr.io/clagomess/docker-php-5.2:curl -f Dockerfile-080-curl .
docker build -t ghcr.io/clagomess/docker-php-5.2:oracle -f Dockerfile-090-oracle .
docker build -t ghcr.io/clagomess/docker-php-5.2:mysql -f Dockerfile-100-mysql .
docker build -t ghcr.io/clagomess/docker-php-5.2 -f Dockerfile-release .
```
