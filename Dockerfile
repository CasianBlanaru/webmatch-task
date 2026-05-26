FROM php:8.4-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

WORKDIR /var/www/html

RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' \
    /etc/apache2/sites-available/*.conf

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    zip \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql intl zip gd

RUN a2dismod mpm_event
RUN rm -f /etc/apache2/mods-enabled/mpm_event.load
RUN rm -f /etc/apache2/mods-enabled/mpm_event.conf

RUN a2enmod rewrite headers

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY . .

RUN composer install --no-dev --no-scripts --prefer-dist --optimize-autoloader

RUN mkdir -p var/cache var/log public/media public/thumbnail public/bundles public/theme

RUN chown -R www-data:www-data var public

RUN printf '#!/bin/bash\napache2-foreground\n' > /usr/local/bin/start \
    && chmod +x /usr/local/bin/start

EXPOSE 80

CMD ["start"]