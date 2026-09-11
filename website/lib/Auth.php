<?php

declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/Database.php';

final class Auth
{
    private Database $db;

    public function __construct(Database $db)
    {
        $this->db = $db;
    }

    public function register(array $input): array
    {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $username = strtolower(trim((string) ($input['username'] ?? '')));
        $displayName = trim((string) ($input['displayName'] ?? ''));
        $password = (string) ($input['password'] ?? '');

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('Valid email is required.', 422);
        }

        if (strlen($password) < 8) {
            throw new InvalidArgumentException('Password must be at least 8 characters.', 422);
        }

        if (!preg_match('/^[a-z0-9_]{3,20}$/', $username)) {
            throw new InvalidArgumentException('Username must be 3-20 chars using letters, numbers, or underscores.', 422);
        }

        if (trim($displayName) === '') {
            throw new InvalidArgumentException('Display name is required.', 422);
        }

        $existingUser = $this->db->fetchOne(
            'SELECT id FROM users WHERE email = :email OR username = :username LIMIT 1',
            ['email' => $email, 'username' => $username]
        );

        if ($existingUser) {
            throw new InvalidArgumentException('Email or username already exists.', 409);
        }

        $userId = $this->uuid();
        $now = gmdate(DATE_ATOM);
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);

        $this->db->execute(
            'INSERT INTO users (id, email, username, password_hash, display_name, bio, photo_url, follower_count, following_count, story_count, created_at, updated_at, deleted_at, status)
             VALUES (:id, :email, :username, :password_hash, :display_name, :bio, :photo_url, 0, 0, 0, :created_at, :updated_at, NULL, :status)',
            [
                'id' => $userId,
                'email' => $email,
                'username' => $username,
                'password_hash' => $passwordHash,
                'display_name' => $displayName,
                'bio' => '',
                'photo_url' => null,
                'created_at' => $now,
                'updated_at' => $now,
                'status' => 'active',
            ]
        );

        $user = $this->db->fetchOne('SELECT * FROM users WHERE id = :id', ['id' => $userId]);
        if (!$user) {
            throw new RuntimeException('User could not be created.', 500);
        }

        return $this->buildUserResponse($user);
    }

    public function login(array $input): array
    {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $password = (string) ($input['password'] ?? '');

        $user = $this->db->fetchOne(
            'SELECT * FROM users WHERE email = :email AND deleted_at IS NULL LIMIT 1',
            ['email' => $email]
        );

        if (!$user || !password_verify($password, (string) $user['password_hash'])) {
            throw new InvalidArgumentException('Invalid email or password.', 401);
        }

        $token = $this->generateToken();
        $tokenHash = hash('sha256', $token);
        $sessionId = $this->uuid();
        $now = gmdate(DATE_ATOM);
        $expiresAt = gmdate(DATE_ATOM, time() + TOKEN_TTL_SECONDS);

        $this->db->execute(
            'INSERT INTO user_sessions (id, user_id, token_hash, created_at, expires_at, revoked_at)
             VALUES (:id, :user_id, :token_hash, :created_at, :expires_at, NULL)',
            [
                'id' => $sessionId,
                'user_id' => $user['id'],
                'token_hash' => $tokenHash,
                'created_at' => $now,
                'expires_at' => $expiresAt,
            ]
        );

        $userData = $this->buildUserResponse($user);
        $userData['token'] = $token;
        return $userData;
    }

    public function logout(string $token): bool
    {
        $tokenHash = hash('sha256', $token);
        $this->db->execute(
            'UPDATE user_sessions SET revoked_at = :revoked_at WHERE token_hash = :token_hash AND revoked_at IS NULL',
            ['revoked_at' => gmdate(DATE_ATOM), 'token_hash' => $tokenHash]
        );
        return true;
    }

    public function getCurrentUserFromBearer(string $authorizationHeader): array
    {
        if (!preg_match('/^Bearer\s+(.*)$/i', trim($authorizationHeader), $matches)) {
            throw new RuntimeException('Missing bearer token.', 401);
        }

        $token = trim($matches[1]);
        if ($token === '') {
            throw new RuntimeException('Missing bearer token.', 401);
        }

        $tokenHash = hash('sha256', $token);
        $session = $this->db->fetchOne(
            'SELECT * FROM user_sessions WHERE token_hash = :token_hash AND revoked_at IS NULL AND expires_at > :now LIMIT 1',
            ['token_hash' => $tokenHash, 'now' => gmdate(DATE_ATOM)]
        );

        if (!$session) {
            throw new RuntimeException('Session expired or invalid.', 401);
        }

        $user = $this->db->fetchOne(
            'SELECT * FROM users WHERE id = :user_id AND deleted_at IS NULL LIMIT 1',
            ['user_id' => $session['user_id']]
        );

        if (!$user) {
            throw new RuntimeException('User not found.', 401);
        }

        return $this->buildUserResponse($user);
    }

    public function getUserById(string $userId): ?array
    {
        $user = $this->db->fetchOne(
            'SELECT * FROM users WHERE id = :user_id AND deleted_at IS NULL LIMIT 1',
            ['user_id' => $userId]
        );

        return $user ? $this->buildUserResponse($user) : null;
    }

    private function buildUserResponse(array $user): array
    {
        return [
            'id' => $user['id'],
            'email' => $user['email'],
            'username' => $user['username'],
            'displayName' => $user['display_name'],
            'bio' => $user['bio'],
            'photoUrl' => $user['photo_url'],
            'followerCount' => (int) $user['follower_count'],
            'followingCount' => (int) $user['following_count'],
            'storyCount' => (int) $user['story_count'],
            'createdAt' => $user['created_at'],
            'updatedAt' => $user['updated_at'],
            'status' => $user['status'],
        ];
    }

    private function uuid(): string
    {
        return strtolower(bin2hex(random_bytes(16)));
    }

    private function generateToken(): string
    {
        return hash_hmac('sha256', uniqid((string) random_int(100000, 999999), true), TOKEN_SECRET);
    }
}
