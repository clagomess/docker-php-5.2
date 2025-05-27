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
