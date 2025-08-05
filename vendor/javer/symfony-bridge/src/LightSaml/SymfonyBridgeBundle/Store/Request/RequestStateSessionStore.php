<?php

namespace LightSaml\SymfonyBridgeBundle\Store\Request;

use LightSaml\Store\Request\AbstractRequestStateArrayStore;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\Session\SessionInterface;

class RequestStateSessionStore extends AbstractRequestStateArrayStore
{
    public function __construct(
        protected RequestStack $requestStack,
        protected string $providerId,
        protected string $prefix = 'saml_request_state_',
    )
    {
    }

    protected function getKey(): string
    {
        return sprintf('%s_%s', $this->providerId, $this->prefix);
    }

    protected function getArray(): array
    {
        return $this->getSession()->get($this->getKey(), []);
    }

    protected function setArray(array $arr): void
    {
        $this->getSession()->set($this->getKey(), $arr);
    }

    protected function getSession(): SessionInterface
    {
        return $this->requestStack->getSession();
    }
}
