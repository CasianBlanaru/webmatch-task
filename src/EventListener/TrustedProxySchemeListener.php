<?php

declare(strict_types=1);

namespace App\EventListener;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Forces Symfony's request object to use HTTPS when the upstream reverse proxy
 * (Caddy / Railway edge) signals it via the X-Forwarded-Proto header.
 *
 * Shopware's asset URL generation relies on $request->getScheme(), which reads
 * from the request object rather than $_SERVER directly. Even though
 * framework.yaml lists 'x-forwarded-proto' as a trusted header, the scheme is
 * only overridden when Symfony's Request::setTrustedProxies() has been called
 * with the correct CIDR range. When SYMFONY_TRUSTED_PROXIES is not set (or the
 * proxy IP falls outside the configured range), the header is ignored and the
 * scheme stays 'http'.
 *
 * This listener runs at the very beginning of the kernel request cycle and
 * writes HTTPS=on / SERVER_PORT=443 into $_SERVER so that every subsequent
 * call to $request->getScheme() — including Shopware's asset URL builder —
 * returns 'https'.
 */
class TrustedProxySchemeListener implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::REQUEST => ['onKernelRequest', 255],
        ];
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();

        if (
            $request->headers->get('X-Forwarded-Proto') === 'https'
            || $request->headers->get('x-forwarded-proto') === 'https'
        ) {
            $_SERVER['HTTPS'] = 'on';
            $_SERVER['SERVER_PORT'] = '443';

            // Also patch the request object's server bag so that
            // $request->getScheme() returns 'https' for this request.
            $request->server->set('HTTPS', 'on');
            $request->server->set('SERVER_PORT', '443');
        }
    }
}
