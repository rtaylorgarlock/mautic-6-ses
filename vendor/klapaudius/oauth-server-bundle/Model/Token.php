<?php

declare(strict_types=1);

/*
 * This file is part of the FOSOAuthServerBundle package.
 *
 * (c) FriendsOfSymfony <http://friendsofsymfony.github.com/>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

namespace FOS\OAuthServerBundle\Model;

use Symfony\Component\Security\Core\User\UserInterface;

class Token implements TokenInterface
{
    /**
     * @var int
     */
    protected $id;

    protected ClientInterface $client;

    protected string $token;

    protected ?int $expiresAt = null;

    protected ?string $scope = null;

    protected ?UserInterface $user = null;

    public function getId()
    {
        return $this->id;
    }

    /**
     * {@inheritdoc}
     */
    public function getClientId(): string
    {
        return $this->getClient()->getPublicId();
    }

    /**
     * {@inheritdoc}
     */
    public function setExpiresAt(?int $timestamp)
    {
        $this->expiresAt = $timestamp;
    }

    /**
     * {@inheritdoc}
     */
    public function getExpiresAt(): ?int
    {
        return $this->expiresAt;
    }

    /**
     * {@inheritdoc}
     */
    public function getExpiresIn(): int
    {
        if ($this->expiresAt) {
            return $this->expiresAt - time();
        }

        return PHP_INT_MAX;
    }

    /**
     * {@inheritdoc}
     */
    public function hasExpired(): bool
    {
        if ($this->expiresAt) {
            return time() > $this->expiresAt;
        }

        return false;
    }

    /**
     * {@inheritdoc}
     */
    public function setToken(string $token)
    {
        $this->token = $token;
    }

    /**
     * {@inheritdoc}
     */
    public function getToken(): string
    {
        return $this->token;
    }

    /**
     * {@inheritdoc}
     */
    public function setScope(?string $scope)
    {
        $this->scope = $scope;
    }

    /**
     * {@inheritdoc}
     */
    public function getScope(): ?string
    {
        return $this->scope;
    }

    /**
     * {@inheritdoc}
     */
    public function setUser(?UserInterface $user)
    {
        $this->user = $user;
    }

    /**
     * {@inheritdoc}
     */
    public function getUser(): ?UserInterface
    {
        return $this->user;
    }

    /**
     * {@inheritdoc}
     *
     * @return mixed
     */
    public function getData()
    {
        return $this->getUser();
    }

    /**
     * {@inheritdoc}
     */
    public function setClient(ClientInterface $client)
    {
        $this->client = $client;
    }

    /**
     * {@inheritdoc}
     */
    public function getClient()
    {
        return $this->client;
    }
}
