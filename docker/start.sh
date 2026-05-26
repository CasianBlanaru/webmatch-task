#!/usr/bin/env bash

set -e

cd /var/www/html

mkdir -p var/cache var/log public/media public/thumbnail public/theme public/bundles
chown -R www-data:www-data var public

if [ -n "$DATABASE_URL" ]; then
  echo "Waiting for database..."
  sleep 10
fi

php -d memory_limit=-1 bin/console cache:clear || true
php -d memory_limit=-1 bin/console assets:install || true

if [ "$SHOPWARE_ES_ENABLED" = "1" ]; then
  php -d memory_limit=-1 bin/console es:index || true
fi

sed -ri -e 's!/var/www/html/public!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

export PORT=${PORT:-8080}

sed -i "s/80/${PORT}/g" /etc/apache2/ports.conf
sed -i "s/:80/:${PORT}/g" /etc/apache2/sites-available/000-default.conf

apache2-foreground
