<?php

declare(strict_types=1);

require_once __DIR__ . '/../config.php';

final class Database
{
    private PDO $pdo;

    public function __construct()
    {
        $this->pdo = new PDO('sqlite:' . DB_PATH, null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        $this->initSchema();
    }

    public function getPdo(): PDO
    {
        return $this->pdo;
    }

    public function initSchema(): void
    {
        $queries = [
            "CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT NOT NULL UNIQUE,
                username TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                display_name TEXT NOT NULL,
                bio TEXT DEFAULT '',
                photo_url TEXT DEFAULT NULL,
                follower_count INTEGER NOT NULL DEFAULT 0,
                following_count INTEGER NOT NULL DEFAULT 0,
                story_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT NULL,
                status TEXT NOT NULL DEFAULT 'active'
            )",
            "CREATE TABLE IF NOT EXISTS user_sessions (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                token_hash TEXT NOT NULL,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                revoked_at TEXT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id)
            )",
            "CREATE TABLE IF NOT EXISTS stories (
                id TEXT PRIMARY KEY,
                author_id TEXT NOT NULL,
                author_name TEXT NOT NULL,
                author_photo TEXT NULL,
                is_anonymous INTEGER NOT NULL DEFAULT 0,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                paragraphs TEXT NOT NULL DEFAULT '[]',
                category TEXT NOT NULL,
                tags TEXT NOT NULL DEFAULT '[]',
                cover_image_url TEXT NULL,
                reading_minutes INTEGER NOT NULL DEFAULT 1,
                like_count INTEGER NOT NULL DEFAULT 0,
                comment_count INTEGER NOT NULL DEFAULT 0,
                view_count INTEGER NOT NULL DEFAULT 0,
                trend_score REAL NOT NULL DEFAULT 0,
                is_published INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT NULL,
                FOREIGN KEY(author_id) REFERENCES users(id)
            )",
            "CREATE TABLE IF NOT EXISTS story_likes (
                story_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                liked_at TEXT NOT NULL,
                PRIMARY KEY (story_id, user_id)
            )",
            "CREATE TABLE IF NOT EXISTS story_comments (
                id TEXT PRIMARY KEY,
                story_id TEXT NOT NULL,
                author_id TEXT NOT NULL,
                author_name TEXT NOT NULL,
                author_photo TEXT NULL,
                text TEXT NOT NULL,
                parent_id TEXT NULL,
                like_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                is_deleted INTEGER NOT NULL DEFAULT 0,
                deleted_at TEXT NULL,
                FOREIGN KEY(story_id) REFERENCES stories(id),
                FOREIGN KEY(author_id) REFERENCES users(id)
            )",
            "CREATE TABLE IF NOT EXISTS bookmarks (
                user_id TEXT NOT NULL,
                story_id TEXT NOT NULL,
                saved_at TEXT NOT NULL,
                PRIMARY KEY (user_id, story_id)
            )",
            "CREATE TABLE IF NOT EXISTS follows (
                follower_id TEXT NOT NULL,
                following_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY (follower_id, following_id)
            )",
            "CREATE TABLE IF NOT EXISTS notifications (
                id TEXT PRIMARY KEY,
                recipient_id TEXT NOT NULL,
                actor_id TEXT NOT NULL,
                actor_name TEXT NOT NULL,
                type TEXT NOT NULL,
                story_id TEXT NULL,
                comment_id TEXT NULL,
                is_read INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                FOREIGN KEY(recipient_id) REFERENCES users(id)
            )",
            "CREATE TABLE IF NOT EXISTS reports (
                id TEXT PRIMARY KEY,
                reporter_id TEXT NOT NULL,
                target_type TEXT NOT NULL,
                target_id TEXT NOT NULL,
                reason TEXT NOT NULL,
                note TEXT DEFAULT '',
                status TEXT NOT NULL DEFAULT 'open',
                created_at TEXT NOT NULL
            )",
            "CREATE TABLE IF NOT EXISTS blocked_users (
                blocker_id TEXT NOT NULL,
                blocked_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY (blocker_id, blocked_id)
            )",
            "CREATE TABLE IF NOT EXISTS recent_searches (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                query TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id)
            )"
        ];

        foreach ($queries as $query) {
            $this->pdo->exec($query);
        }
    }

    public function execute(string $sql, array $params = []): bool
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return true;
    }

    public function fetchOne(string $sql, array $params = []): ?array
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        $row = $stmt->fetch();
        return $row === false ? null : $row;
    }

    public function fetchAll(string $sql, array $params = []): array
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function lastInsertId(): string
    {
        return (string) $this->pdo->lastInsertId();
    }
}
