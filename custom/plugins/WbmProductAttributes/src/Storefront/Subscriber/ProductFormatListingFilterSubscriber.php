<?php declare(strict_types=1);

namespace Wbm\ProductAttributes\Storefront\Subscriber;

use Shopware\Core\Content\Product\Events\ProductListingCollectFilterEvent;
use Shopware\Core\Content\Product\SalesChannel\Listing\Filter;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Aggregation\Bucket\TermsAggregation;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Filter\AndFilter;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Filter\EqualsAnyFilter;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\Request;
use Wbm\ProductAttributes\AttributeNames;

class ProductFormatListingFilterSubscriber implements EventSubscriberInterface
{
    private const FIELD = 'product.customFields.' . AttributeNames::PRODUCT_FORMAT;
    private const AGGREGATION_NAME = 'wbm-product-format';

    public static function getSubscribedEvents(): array
    {
        return [
            ProductListingCollectFilterEvent::class => 'addProductFormatFilter',
        ];
    }

    public function addProductFormatFilter(ProductListingCollectFilterEvent $event): void
    {
        $event->getFilters()->add($this->createFilter($event->getRequest()));
    }

    public function createFilter(Request $request): Filter
    {
        $formats = $this->getSelectedFormats($request);

        return new Filter(
            AttributeNames::PRODUCT_FORMAT_FILTER,
            $formats !== [],
            [new TermsAggregation(self::AGGREGATION_NAME, self::FIELD)],
            $formats === [] ? new AndFilter([]) : new EqualsAnyFilter(self::FIELD, $formats),
            $formats
        );
    }

    /**
     * @return list<non-empty-string>
     */
    private function getSelectedFormats(Request $request): array
    {
        $formats = $request->query->get(AttributeNames::PRODUCT_FORMAT_FILTER, '');

        if ($request->isMethod(Request::METHOD_POST)) {
            $formats = $request->request->get(AttributeNames::PRODUCT_FORMAT_FILTER, '');
        }

        if (\is_string($formats)) {
            $formats = explode('|', $formats);
        }

        $formats = array_filter(array_map(static fn (mixed $value): string => trim((string) $value), (array) $formats));

        return array_values(array_unique($formats));
    }
}
