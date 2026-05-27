# Railway Deployment Notes

This setup is intentionally small and pragmatic.

The goal is simply to make the Shopware storefront and Administration reachable online for the hiring task.

## Railway Services

Recommended:

- 1x App Service (Docker deployment)
- 1x MySQL or MariaDB service

Optional:

- OpenSearch service

For the Railway free tier I would personally keep OpenSearch disabled unless it is really needed for the demo.

## Environment Variables

Example:

```env
APP_ENV=prod
APP_URL=https://your-app.up.railway.app
APP_SECRET=change-me
DATABASE_URL=mysql://root:password@host:3306/shopware
MAILER_DSN=null://null
SHOPWARE_ES_ENABLED=0
SYMFONY_TRUSTED_PROXIES=private_ranges
```

## Deploy Steps

1. Push repository to GitHub
2. Create new Railway project
3. Connect GitHub repository
4. Add MySQL service
5. Set environment variables
6. Deploy

## Plugin Installation

Inside Railway shell:

```bash
php bin/console plugin:refresh
php bin/console plugin:install --activate WbmProductAttributes
php bin/console database:migrate WbmProductAttributes --all
```

## OpenSearch

OpenSearch is optional here.

The plugin itself works without it.

For a hiring-task demo I would rather keep the deployment stable than spend a lot of time debugging OpenSearch on a free container setup.

If OpenSearch is enabled later:

```bash
php bin/console es:index
```

## Persistent Storage

Railway containers are ephemeral.

For a temporary demo that is usually acceptable, but media uploads and cache files are not guaranteed to persist forever.

## Realistic Limitations

This setup is not intended as a long-term production deployment.

It is mainly for:
- screenshots
- short demo videos
- verifying the plugin online
- showing the Administration and storefront filter
