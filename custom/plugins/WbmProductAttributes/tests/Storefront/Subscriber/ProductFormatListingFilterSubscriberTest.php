<?php declare(strict_types=1);

namespace Wbm\ProductAttributes\Tests\Storefront\Subscriber;

use PHPUnit\Framework\TestCase;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Aggregation\Bucket\TermsAggregation;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Filter\AndFilter;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Filter\EqualsAnyFilter;
use Symfony\Component\HttpFoundation\Request;
use Wbm\ProductAttributes\AttributeNames;
use Wbm\ProductAttributes\Storefront\Subscriber\ProductFormatListingFilterSubscriber;

class ProductFormatListingFilterSubscriberTest extends TestCase
{
    public function testCreatesUnfilteredAggregationFilter(): void
    {
        $filter = (new ProductFormatListingFilterSubscriber())->createFilter(new Request());

        static::assertSame(AttributeNames::PRODUCT_FORMAT_FILTER, $filter->getName());
        static::assertFalse($filter->isFiltered());
        static::assertSame([], $filter->getValues());
        static::assertInstanceOf(AndFilter::class, $filter->getFilter());

        $aggregation = $filter->getAggregations()[0] ?? null;
        static::assertInstanceOf(TermsAggregation::class, $aggregation);
        static::assertSame('wbm-product-format', $aggregation->getName());
        static::assertSame(['product.customFields.productFormat'], $aggregation->getFields());
    }

    public function testCreatesEqualsAnyFilterForSelectedFormats(): void
    {
        $request = new Request([AttributeNames::PRODUCT_FORMAT_FILTER => 'Bücher|Hörbuch|Bücher']);

        $filter = (new ProductFormatListingFilterSubscriber())->createFilter($request);

        static::assertTrue($filter->isFiltered());
        static::assertSame(['Bücher', 'Hörbuch'], $filter->getValues());
        static::assertInstanceOf(EqualsAnyFilter::class, $filter->getFilter());
        static::assertSame('product.customFields.productFormat', $filter->getFilter()->getField());
        static::assertSame(['Bücher', 'Hörbuch'], $filter->getFilter()->getValue());
    }
}
