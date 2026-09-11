<?php

declare(strict_types=1);

final class Validation
{
    public const PROFANITY_WORDS = [
        'damn', 'shit', 'fuck', 'crap', 'idiot', 'stupid', 'moron', 'bastard',
        'dumbass', 'hate', 'kill', 'murder', 'slur', 'nazi', 'whore', 'sexist'
    ];

    public static function containsProfanity(string $value): bool
    {
        $normalized = strtolower(trim($value));
        if ($normalized === '') {
            return false;
        }

        foreach (self::PROFANITY_WORDS as $word) {
            if (str_contains($normalized, $word)) {
                return true;
            }
        }

        return false;
    }

    public static function requireSafeText(string $fieldName, string $value, int $minLen = 1, int $maxLen = 1000): string
    {
        $trimmed = trim($value);
        if (mb_strlen($trimmed) < $minLen || mb_strlen($trimmed) > $maxLen) {
            throw new InvalidArgumentException(sprintf('%s must be between %d and %d characters.', $fieldName, $minLen, $maxLen), 422);
        }

        if (self::containsProfanity($trimmed)) {
            throw new InvalidArgumentException(sprintf('%s contains unsupported language.', $fieldName), 422);
        }

        return $trimmed;
    }

    public static function validateStoryPayload(array $payload): array
    {
        $title = self::requireSafeText('Title', (string) ($payload['title'] ?? ''), 3, 120);
        $body = self::requireSafeText('Story body', (string) ($payload['body'] ?? ''), 50, 20000);

        $wordCount = preg_split('/\s+/', trim($body));
        $wordCount = is_array($wordCount) ? count(array_filter($wordCount, static fn ($word) => trim((string) $word) !== '')) : 0;
        if ($wordCount < 20) {
            throw new InvalidArgumentException('Story body must contain at least 20 words.', 422);
        }

        $category = trim((string) ($payload['category'] ?? ''));
        if ($category === '') {
            throw new InvalidArgumentException('Category is required.', 422);
        }

        $tags = [];
        foreach ((array) ($payload['tags'] ?? []) as $tag) {
            $tagValue = strtolower(trim((string) $tag));
            if ($tagValue === '') {
                continue;
            }
            if (!preg_match('/^[a-z0-9_-]{2,20}$/', $tagValue)) {
                throw new InvalidArgumentException('Each tag must be 2-20 chars, lowercase, and contain no spaces.', 422);
            }
            if (self::containsProfanity($tagValue)) {
                throw new InvalidArgumentException('One or more tags contain unsupported language.', 422);
            }
            $tags[] = $tagValue;
        }
        if (count($tags) > 5) {
            throw new InvalidArgumentException('You can have up to 5 tags only.', 422);
        }

        return [
            'title' => $title,
            'body' => $body,
            'category' => $category,
            'tags' => array_values(array_unique($tags)),
        ];
    }

    public static function validateProfilePayload(array $payload): array
    {
        $displayName = trim((string) ($payload['displayName'] ?? ''));
        $username = strtolower(trim((string) ($payload['username'] ?? '')));

        if ($displayName === '') {
            throw new InvalidArgumentException('Display name is required.', 422);
        }

        if (!preg_match('/^[a-z0-9_]{3,20}$/', $username)) {
            throw new InvalidArgumentException('Username must be 3-20 chars using lowercase letters, numbers, or underscores.', 422);
        }

        $bio = trim((string) ($payload['bio'] ?? ''));
        if (mb_strlen($bio) > 300) {
            throw new InvalidArgumentException('Bio must be 300 characters or fewer.', 422);
        }

        if (self::containsProfanity($displayName) || self::containsProfanity($bio) || self::containsProfanity($username)) {
            throw new InvalidArgumentException('Profile contains unsupported language.', 422);
        }

        return ['displayName' => $displayName, 'username' => $username, 'bio' => $bio];
    }
}
