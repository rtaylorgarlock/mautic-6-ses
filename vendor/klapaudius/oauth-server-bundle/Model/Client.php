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

use FOS\OAuthServerBundle\Util\Random;
use OAuth2\OAuth2;

class Client implements ClientInterface
{
    /**
     * @var int
     */
    protected $id;

    protected ?string $randomId = null;

    protected ?string $secret = null;

    protected array $redirectUris = [];

    protected array $allowedGrantTypes = [];

    public function __construct()
    {
        $this->allowedGrantTypes[] = OAuth2::GRANT_TYPE_AUTH_CODE;

        $this->setRandomId(Random::generateToken());
        $this->setSecret(Random::generateToken());
    }

    public function getId()
    {
        return $this->id;
    }

    /**
     * {@inheritdoc}
     */
    public function setRandomId(string $random)
    {
        $this->randomId = $random;
    }

    /**
     * {@inheritdoc}
     */
    public function getRandomId(): ?string
    {
        return $this->randomId;
    }

    /**
     * {@inheritdoc}
     */
    public function getPublicId(): string
    {
        return sprintf('%s_%s', $this->getId(), $this->getRandomId());
    }

    /**
     * {@inheritdoc}
     */
    public function setSecret($secret)
    {
        $this->secret = $secret;
    }

    /**
     * {@inheritdoc}
     */
    public function getSecret(): ?string
    {
        return $this->secret;
    }

    /**
     * {@inheritdoc}
     */
    public function checkSecret(string $secret): bool
    {
        return null === $this->secret || $secret === $this->secret;
    }

    /**
     * {@inheritdoc}
     */
    public function setRedirectUris(array $redirectUris)
    {
        $this->redirectUris = $redirectUris;
    }

    /**
     * {@inheritdoc}
     */
    public function getRedirectUris(): array
    {
        return $this->redirectUris;
    }

    /**
     * {@inheritdoc}
     */
    public function setAllowedGrantTypes(array $grantTypes)
    {
        $this->allowedGrantTypes = $grantTypes;
    }

    /**
     * {@inheritdoc}
     */
    public function getAllowedGrantTypes(): array
    {
        return $this->allowedGrantTypes;
    }

    public function getRoles(): array
    {
        return ['ROLE_USER'];
    }

    public function getPassword(): string
    {
        return $this->getSecret();
    }

    public function getSalt(): ?string
    {
        // Will use auto salt system
        return null;
    }

    public function eraseCredentials(): void
    {
        // nothind to erase
    }

    public function getUsername(): string
    {
        return $this->getRandomId();
    }

    public function getUserIdentifier(): string
    {
        return $this->getRandomId();
    }
}
