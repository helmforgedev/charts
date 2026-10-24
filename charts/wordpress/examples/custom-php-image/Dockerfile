# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0

ARG WORDPRESS_RUNTIME_IMAGE=docker.io/library/wordpress:7.1.3-apache@sha256:d42f63cb89ad0eab272c4b393164e63830d0df270009907919f7dcce52b1a20b
ARG WORDPRESS_CLI_IMAGE=docker.io/library/wordpress:cli-php8.3@sha256:661db880e953da051abcac6c0a769767b995a82cd52101c003ca7438dd427d7d

FROM ${WORDPRESS_RUNTIME_IMAGE} AS runtime
RUN docker-php-ext-install -j"$(nproc)" pdo_mysql \
    && php -m | grep -Fx pdo_mysql

FROM ${WORDPRESS_CLI_IMAGE} AS cli
USER root
RUN docker-php-ext-install -j"$(nproc)" pdo_mysql \
    && php -m | grep -Fx pdo_mysql
USER www-data
