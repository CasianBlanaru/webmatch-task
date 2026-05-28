<?php

declare(strict_types=1);

namespace App\Service;

use Shopware\Core\Framework\Routing\UrlGeneratorInterface;

/**
 * Decorates Shopware's router service to ensure every absolute URL it generates
 * uses the HTTPS scheme.
 *
 * Shopware's asset URL generation calls $request->getScheme() on the internal
 * (HTTP) request, so even with X-Forwarded-Proto headers and trusted-proxy
 * configuration in place the generated URLs can still carry an 'http://' prefix.
 * This decorator intercepts every call to generate() and rewrites the scheme for
 * absolute URLs before they are returned to the caller.
 */
class HttpsUrlGenerator implements UrlGeneratorInterface
{
    public function __construct(private readonly UrlGeneratorInterface $inner)
    {
    }

    public function generate(string $name, array $parameters = [], int $referenceType = self::ABSOLUTE_PATH): string
    {
        $url = $this->inner->generate($name, $parameters, $referenceType);

        // Force HTTPS for absolute URLs only; relative paths are left untouched.
        if ($referenceType === self::ABSOLUTE_URL && str_starts_with($url, 'http://')) {
            $url = 'https://' . substr($url, 7);
        }

        return $url;
    }
}
