# WbmProductAttributes

Small Shopware 6 plugin for the hiring task.

The plugin lives in custom/plugins/WbmProductAttributes.  
I worked against the code in this repository where shopware/core is pinned to v6.7.10.1.

The task itself mentions 6.7.9.x, so the plugin constraint allows both:

text ~6.7.9 || ~6.7.10 

## Production Demo

Storefront:
https://webmatch-task-production.up.railway.app/

Administration:
https://webmatch-task-production.up.railway.app/admin

Admin login:

- Username: admin
- Password: WebmatchDemo2026!

The production demo contains dummy products for testing the product format filter and search.

## Setup

bash composer install php bin/console plugin:refresh php bin/console plugin:install --activate WbmProductAttributes php bin/console database:migrate WbmProductAttributes --all php bin/console cache:clear bin/build-administration.sh bin/build-storefront.sh 

If Elasticsearch/OpenSearch is enabled:

bash php bin/console es:index 

In my local setup the Docker database was exposed on a random port, so I used DATABASE_URL inline for some console commands instead of changing the whole environment config.

I also had to increase the PHP memory limit for some Shopware console tasks locally:

bash php -d memory_limit=-1 

## Approach

I decided to use Shopware custom fields instead of building a DAL ProductEntity extension.

For these two fields it felt like the simpler and more practical solution. Shopware already handles product custom fields inside the Specifications tab, persists them through the normal product flow and includes searchable custom fields in the Elasticsearch/OpenSearch mapping.

A dedicated extension table would make more sense if the imported API data became more relational or needed stricter validation/reporting. For this task it added more complexity than necessary.

The note about 50+ future API attributes is the main tradeoff here. I would not mirror every upstream field directly into Shopware custom fields forever. If the amount of metadata grows significantly, I would probably revisit a dedicated extension structure later.

## Implemented

### productIdFromApi

Integer custom field attached to products.

- visible in Specifications
- readonly in the Administration UI

### productFormat

Editable text custom field for values like:

- Bücher
- Hörbuch
- DVD
- CD-ROM

The field is:
- editable in Specifications
- added as a column in Catalogues > Products
- included in product search configuration

The migration creates one custom field set, assigns it to product, creates both fields and updates the product search configuration for:

text customFields.productFormat 

## Storefront Filter

The storefront filter is registered through ProductListingCollectFilterEvent.

It adds:
- a TermsAggregation
- an EqualsAnyFilter

for:

text product.customFields.productFormat 

This keeps the filter inside Shopware’s normal listing pipeline and works with Elasticsearch/OpenSearch criteria parsing.

The Twig implementation only renders the aggregation buckets using the existing Shopware multi-select filter structure. No custom JavaScript was added.

Searching for values like Bücher should also return matching products after rebuilding the ES/OpenSearch index.

## Verification

Static checks:

bash find custom/plugins/WbmProductAttributes -name '*.php' -print -exec php -l {} \; composer validate custom/plugins/WbmProductAttributes/composer.json --strict php -r '...json_decode snippet files with JSON_THROW_ON_ERROR...' php -r '...DOMDocument load services.xml/phpunit.xml.dist...' php -r '...MigrationStep::getPlausibleCreationTimestamp()...' 

Local Shopware checks:

bash php -d memory_limit=-1 bin/console plugin:refresh php -d memory_limit=-1 bin/console plugin:install --activate WbmProductAttributes --no-interaction php -d memory_limit=-1 bin/console lint:container php -d memory_limit=-1 bin/console lint:twig custom/plugins/WbmProductAttributes/src/Resources/views php -d memory_limit=-1 bin/console assets:install 

I also checked the database manually after installation:
- both custom fields exist
- the field set is assigned to product
- productIdFromApi is disabled in Administration config
- customFields.productFormat exists in product_search_config_field
- the plugin is installed and active

The storefront filter behavior was additionally checked with a small PHP script against the actual Shopware classes.

## Tests

The test scope is intentionally small.

This was a timed task, so I focused more on the actual Shopware integration than on building a large automated test setup.

The plugin currently contains PHPUnit tests for:
- migration timestamp validity
- storefront filter construction

The storefront filter test verifies that selected values create an EqualsAnyFilter for:

text product.customFields.productFormat 

In a real project the next step would probably be an integration test that boots Shopware, installs the plugin, indexes products and verifies the storefront listing behavior against a real database and OpenSearch instance.

I did not add that here because the local Docker/OpenSearch setup was unstable during implementation and I preferred prioritizing the plugin itself.

## Still Open

I did not do a full browser walkthrough of the Administration and Storefront before writing this README.

The implementation was mainly verified against:
- the actual Shopware 6.7 source
- local installation state
- database structure
- console checks
- filter construction

OpenSearch was present locally but not fully debugged because of Docker/macOS storage issues during setup.

## Tradeoffs

The filter currently uses the raw productFormat value as both label and filter value.

That keeps the implementation small, but inconsistent upstream spelling would create separate filter options.

productIdFromApi is readonly in the Administration UI only. API clients with product write permissions could still modify it. In a real project I would probably enforce that closer to the import layer or with write validation depending on the business rules.

The custom-field approach keeps the plugin lightweight, but too many API fields could eventually make the custom-field setup and ES/OpenSearch mapping noisy. That is why I would keep only business-relevant fields in this structure.

## AI Usage

I used Cursor and ChatGPT mainly for boilerplate support and for checking Shopware implementation details more quickly.

The useful part was validating the actual Shopware 6.7 code paths around:
- custom field rendering
- product listing filters
- Elasticsearch/OpenSearch criteria parsing

All generated code was reviewed manually and adjusted where necessary.

One suggestion I intentionally rejected was building a dedicated DAL product extension with a separate table. Technically valid, but for this task it added more moving parts than I felt were necessary.

## Suggested Commit Structure

1. Add WBM product custom fields
2. Add product format admin column
3. Add storefront product format filter
4. Add focused plugin tests
5. Document implementation decisions

❤️ Casian Blanaru
