# Stage 1: Clone Moodle source
# After cloning, assert that the code Moodle actually ships on this branch matches
# MOODLE_VERSION — Moodle's own public/version.php $branch (e.g. '502') must equal the
# number in MOODLE_VERSION. Since the image tags are derived from the same
# MOODLE_VERSION, this guarantees the published tag reflects the incorporated version.
# A mismatch (typo'd or mislabeled branch) fails the build.
FROM alpine/git AS moodle-src
ARG MOODLE_VERSION=MOODLE_502_STABLE
RUN git clone --depth=1 --branch=${MOODLE_VERSION} \
        https://github.com/moodle/moodle.git /moodle \
 && expected=$(echo "${MOODLE_VERSION}" | grep -oE '[0-9]+' | head -n1) \
 && actual=$(grep -oE "branch[[:space:]]*=[[:space:]]*'[0-9]+'" /moodle/public/version.php | grep -oE '[0-9]+' | head -n1) \
 && echo "Moodle version check: MOODLE_VERSION expects branch=${expected}, public/version.php reports branch=${actual}" \
 && [ -n "${expected}" ] && [ "${expected}" = "${actual}" ] \
        || { echo "ERROR: incorporated Moodle version (${actual}) does not match MOODLE_VERSION (${expected})"; exit 1; }

# Stage 2: Runtime
FROM php:8.5-apache

RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libxml2-dev \
    libicu-dev \
    libldap2-dev \
    libmemcached-dev \
    libsodium-dev \
    zlib1g-dev \
    curl \
    ghostscript \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    zip \
    xml \
    intl \
    soap \
    opcache \
    mysqli \
    pdo \
    pdo_mysql \
    ldap \
    exif \
    sodium

RUN pecl install redis && docker-php-ext-enable redis

RUN { \
    echo "log_errors = On"; \
    echo "display_errors = Off"; \
    echo "max_input_vars = 5000"; \
    echo "memory_limit = 512M"; \
    echo "upload_max_filesize = 20M"; \
    echo "post_max_size = 20M"; \
    echo "opcache.memory_consumption = 256"; \
    echo "opcache.max_accelerated_files = 10000"; \
    echo "opcache.revalidate_freq = 60"; \
    echo "opcache.save_comments = 1"; \
    echo "opcache.validate_timestamps = 1"; \
    } > /usr/local/etc/php/conf.d/moodle.ini

RUN a2enmod rewrite

RUN ln -sf /dev/stderr /var/log/apache2/error.log \
    && ln -sf /dev/stdout /var/log/apache2/access.log

# Point Apache DocumentRoot to public/ (required by Moodle 5.1+)
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

COPY --from=moodle-src /moodle /var/www/html

RUN apt-get update && apt-get install -y git unzip \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && cd /var/www/html && composer install --no-dev --classmap-authoritative \
    && apt-get purge -y git unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* \
    && rm /usr/local/bin/composer

COPY config.php /var/www/html/config.php

RUN chown -R www-data:www-data /var/www/html

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
