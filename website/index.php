<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/Database.php';
require_once __DIR__ . '/lib/Backup.php';
require_once __DIR__ . '/lib/Auth.php';
require_once __DIR__ . '/lib/Validation.php';
require_once __DIR__ . '/lib/Admin.php';

function jsonResponse(int $status, array $payload): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

function readJsonBody(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function parseSegments(): array
{
    $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?? '/';
    $normalized = str_replace(
        ['/webstore', '/website', '/app/index.php', '/index.php'],
        '',
        $uri
    );
    $segments = array_values(array_filter(explode('/', $normalized), static fn ($segment) => $segment !== '' && $segment !== '/'));
    return $segments;
}

function uuid(): string
{
    return strtolower(bin2hex(random_bytes(16)));
}

function parseDate(string $value): string
{
    return $value !== '' ? $value : gmdate(DATE_ATOM);
}

function trimTags(array $tags): array
{
    $clean = [];
    foreach ($tags as $tag) {
        $value = strtolower(trim((string) $tag));
        if ($value !== '' && preg_match('/^[a-z0-9_-]{2,20}$/', $value)) {
            $clean[] = $value;
        }
    }
    return array_values(array_unique(array_slice($clean, 0, 5)));
}

function paragraphsFromBody(string $body): array
{
    $blocks = preg_split('/\n\s*\n/', trim($body));
    $clean = [];
    foreach ($blocks as $block) {
        $block = trim($block);
        if ($block !== '') {
            $clean[] = $block;
        }
    }
    return $clean !== [] ? $clean : [trim($body)];
}

function readingMinutesFromBody(string $body): int
{
    $words = preg_split('/\s+/', trim($body));
    $count = is_array($words) ? count(array_filter($words, static fn ($word) => trim($word) !== '')) : 0;
    return max(1, (int) ceil($count / 200));
}

$db = new Database();
$auth = new Auth($db);
$admin = new Admin($db);
$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
$segments = parseSegments();
$route = $segments[0] ?? 'health';
$resourceId = $segments[1] ?? null;
$payload = readJsonBody();

try {
    if ($route === 'health') {
        jsonResponse(200, ['status' => 'ok', 'app' => APP_NAME, 'db' => DB_PATH]);
    }

    if ($route === 'auth') {
        $action = $segments[1] ?? null;

        if ($method === 'POST' && $action === 'register') {
            $validated = Validation::validateProfilePayload($payload);
            $user = $auth->register([
                'email' => $payload['email'] ?? '',
                'username' => $validated['username'],
                'displayName' => $validated['displayName'],
                'password' => $payload['password'] ?? '',
            ]);
            jsonResponse(201, ['message' => 'User registered successfully.', 'user' => $user]);
        }

        if ($method === 'POST' && $action === 'login') {
            $email = trim((string) ($payload['email'] ?? ''));
            $password = (string) ($payload['password'] ?? '');
            if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8) {
                throw new InvalidArgumentException('Invalid email or password.', 401);
            }
            $user = $auth->login($payload);
            jsonResponse(200, ['message' => 'Login successful.', 'user' => $user]);
        }

        if ($method === 'POST' && $action === 'logout') {
            $token = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
            if (preg_match('/^Bearer\s+(.*)$/i', trim($token), $matches)) {
                $auth->logout(trim($matches[1]));
            }
            jsonResponse(200, ['message' => 'Logged out successfully.']);
        }

        if ($method === 'GET' && $action === 'me') {
            $user = $auth->getCurrentUserFromBearer($_SERVER['HTTP_AUTHORIZATION'] ?? '');
            jsonResponse(200, ['user' => $user]);
        }

        throw new RuntimeException('Invalid auth route.', 404);
    }

    $currentUser = $auth->getCurrentUserFromBearer($_SERVER['HTTP_AUTHORIZATION'] ?? '');
    $userId = $currentUser['id'];

    if ($route === 'users' && $method === 'GET') {
        $user = $auth->getUserById($resourceId ?? $userId);
        if (!$user) {
            throw new RuntimeException('User not found.', 404);
        }
        jsonResponse(200, ['user' => $user]);
    }

    if ($route === 'users' && $method === 'PUT') {
        $profile = Validation::validateProfilePayload(
            [
                'displayName' => $payload['displayName'] ?? $currentUser['displayName'],
                'username' => $payload['username'] ?? $currentUser['username'],
                'bio' => $payload['bio'] ?? $currentUser['bio'],
            ]
        );
        $displayName = $profile['displayName'];
        $bio = $profile['bio'];
        $photoUrl = trim((string) ($payload['photoUrl'] ?? ''));
        $username = $profile['username'];

        if ($username !== $currentUser['username']) {
            $exists = $db->fetchOne('SELECT id FROM users WHERE username = :username AND id != :id LIMIT 1', ['username' => $username, 'id' => $userId]);
            if ($exists) {
                throw new InvalidArgumentException('Username already taken.', 409);
            }
        }

        $db->execute(
            'UPDATE users SET username = :username, display_name = :display_name, bio = :bio, photo_url = :photo_url, updated_at = :updated_at WHERE id = :id',
            [
                'username' => $username,
                'display_name' => $displayName,
                'bio' => $bio,
                'photo_url' => $photoUrl === '' ? null : $photoUrl,
                'updated_at' => gmdate(DATE_ATOM),
                'id' => $userId,
            ]
        );

        Backup::save('users', ['id' => $userId, 'update' => $payload], $userId, 'update');

        $updatedUser = $auth->getUserById($userId);
        jsonResponse(200, ['message' => 'Profile updated successfully.', 'user' => $updatedUser]);
    }

    if ($route === 'stories' && $resourceId === null && $method === 'GET') {
        $limit = min(50, max(1, (int) ($_GET['limit'] ?? 20)));
        $where = 'WHERE deleted_at IS NULL AND is_published = 1';
        $params = [];

        if (isset($_GET['category'])) {
            $where .= ' AND category = :category';
            $params['category'] = $_GET['category'];
        }

        if (isset($_GET['authorId'])) {
            $where .= ' AND author_id = :author_id';
            $params['author_id'] = $_GET['authorId'];
        }

        $sql = "SELECT * FROM stories {$where} ORDER BY created_at DESC LIMIT :limit";
        $stmt = $db->getPdo()->prepare($sql);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        foreach ($params as $key => $value) {
            $stmt->bindValue(':' . $key, $value);
        }
        $stmt->execute();
        $stories = $stmt->fetchAll();

        jsonResponse(200, ['stories' => $stories]);
    }

    if ($route === 'stories' && $method === 'POST') {
        $validated = Validation::validateStoryPayload($payload);
        $title = $validated['title'];
        $body = $validated['body'];
        $category = $validated['category'];
        $tags = trimTags($validated['tags']);

        $storyId = uuid();
        $now = gmdate(DATE_ATOM);
        $story = [
            'id' => $storyId,
            'authorId' => $userId,
            'authorName' => $currentUser['displayName'],
            'authorPhoto' => $currentUser['photoUrl'],
            'isAnonymous' => !empty($payload['isAnonymous']) ? 1 : 0,
            'title' => $title,
            'body' => $body,
            'paragraphs' => json_encode(paragraphsFromBody($body), JSON_UNESCAPED_SLASHES),
            'category' => $category,
            'tags' => json_encode($tags, JSON_UNESCAPED_SLASHES),
            'coverImageUrl' => !empty($payload['coverImageUrl']) ? trim((string) $payload['coverImageUrl']) : null,
            'readingMinutes' => readingMinutesFromBody($body),
            'likeCount' => 0,
            'commentCount' => 0,
            'viewCount' => 0,
            'trendScore' => 0,
            'isPublished' => 1,
            'createdAt' => $now,
            'updatedAt' => $now,
            'deletedAt' => null,
        ];

        $db->execute(
            'INSERT INTO stories (id, author_id, author_name, author_photo, is_anonymous, title, body, paragraphs, category, tags, cover_image_url, reading_minutes, like_count, comment_count, view_count, trend_score, is_published, created_at, updated_at, deleted_at)
             VALUES (:id, :author_id, :author_name, :author_photo, :is_anonymous, :title, :body, :paragraphs, :category, :tags, :cover_image_url, :reading_minutes, :like_count, :comment_count, :view_count, :trend_score, :is_published, :created_at, :updated_at, :deleted_at)',
            [
                'id' => $storyId,
                'author_id' => $userId,
                'author_name' => $currentUser['displayName'],
                'author_photo' => $currentUser['photoUrl'],
                'is_anonymous' => !empty($payload['isAnonymous']) ? 1 : 0,
                'title' => $title,
                'body' => $body,
                'paragraphs' => json_encode(paragraphsFromBody($body), JSON_UNESCAPED_SLASHES),
                'category' => $category,
                'tags' => json_encode($tags, JSON_UNESCAPED_SLASHES),
                'cover_image_url' => !empty($payload['coverImageUrl']) ? trim((string) $payload['coverImageUrl']) : null,
                'reading_minutes' => readingMinutesFromBody($body),
                'like_count' => 0,
                'comment_count' => 0,
                'view_count' => 0,
                'trend_score' => 0,
                'is_published' => 1,
                'created_at' => $now,
                'updated_at' => $now,
                'deleted_at' => null,
            ]
        );

        Backup::save('stories', $story, $storyId, 'create');
        $created = $db->fetchOne('SELECT * FROM stories WHERE id = :id LIMIT 1', ['id' => $storyId]);
        jsonResponse(201, ['message' => 'Story created successfully.', 'story' => $created]);
    }

    if ($route === 'stories' && $method === 'PUT' && $resourceId) {
        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id AND deleted_at IS NULL LIMIT 1', ['id' => $resourceId]);
        if (!$story) {
            throw new RuntimeException('Story not found.', 404);
        }
        if ((string) $story['author_id'] !== $userId) {
            throw new RuntimeException('Only the author can edit a story.', 403);
        }

        $mergedPayload = [
            'title' => $payload['title'] ?? $story['title'],
            'body' => $payload['body'] ?? $story['body'],
            'category' => $payload['category'] ?? $story['category'],
            'tags' => $payload['tags'] ?? json_decode((string) $story['tags'], true) ?: [],
        ];
        $validated = Validation::validateStoryPayload($mergedPayload);
        $title = $validated['title'];
        $body = $validated['body'];
        $category = $validated['category'];
        $tags = trimTags($validated['tags']);

        $db->execute(
            'UPDATE stories SET title = :title, body = :body, paragraphs = :paragraphs, category = :category, tags = :tags, cover_image_url = :cover_image_url, reading_minutes = :reading_minutes, updated_at = :updated_at WHERE id = :id',
            [
                'title' => $title,
                'body' => $body,
                'paragraphs' => json_encode(paragraphsFromBody($body), JSON_UNESCAPED_SLASHES),
                'category' => $category,
                'tags' => json_encode($tags, JSON_UNESCAPED_SLASHES),
                'cover_image_url' => isset($payload['coverImageUrl']) ? trim((string) $payload['coverImageUrl']) : $story['cover_image_url'],
                'reading_minutes' => readingMinutesFromBody($body),
                'updated_at' => gmdate(DATE_ATOM),
                'id' => $resourceId,
            ]
        );

        Backup::save('stories', ['id' => $resourceId, 'update' => $payload], $resourceId, 'update');
        $updated = $db->fetchOne('SELECT * FROM stories WHERE id = :id LIMIT 1', ['id' => $resourceId]);
        jsonResponse(200, ['message' => 'Story updated successfully.', 'story' => $updated]);
    }

    if ($route === 'stories' && $method === 'DELETE' && $resourceId) {
        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id AND deleted_at IS NULL LIMIT 1', ['id' => $resourceId]);
        if (!$story) {
            throw new RuntimeException('Story not found.', 404);
        }
        if ((string) $story['author_id'] !== $userId) {
            throw new RuntimeException('Only the author can delete a story.', 403);
        }

        $db->execute('UPDATE stories SET deleted_at = :deleted_at, updated_at = :updated_at WHERE id = :id', ['deleted_at' => gmdate(DATE_ATOM), 'updated_at' => gmdate(DATE_ATOM), 'id' => $resourceId]);
        Backup::save('stories', ['id' => $resourceId, 'deletedAt' => gmdate(DATE_ATOM)], $resourceId, 'soft-delete');
        jsonResponse(200, ['message' => 'Story soft deleted successfully.']);
    }

    if ($route === 'stories' && $resourceId && $method === 'GET') {
        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id AND deleted_at IS NULL LIMIT 1', ['id' => $resourceId]);
        if (!$story) {
            throw new RuntimeException('Story not found.', 404);
        }
        $db->execute('UPDATE stories SET view_count = view_count + 1, updated_at = :updated_at WHERE id = :id', ['updated_at' => gmdate(DATE_ATOM), 'id' => $resourceId]);
        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id LIMIT 1', ['id' => $resourceId]);
        jsonResponse(200, ['story' => $story]);
    }

    if ($route === 'stories' && $resourceId && $segments[2] === 'like' && $method === 'POST') {
        $storyId = $resourceId;
        $exists = $db->fetchOne('SELECT 1 FROM story_likes WHERE story_id = :story_id AND user_id = :user_id LIMIT 1', ['story_id' => $storyId, 'user_id' => $userId]);
        if ($exists) {
            $db->execute('DELETE FROM story_likes WHERE story_id = :story_id AND user_id = :user_id', ['story_id' => $storyId, 'user_id' => $userId]);
            $likeCount = (int) $db->fetchOne('SELECT COUNT(*) AS count FROM story_likes WHERE story_id = :story_id', ['story_id' => $storyId])['count'];
            $db->execute('UPDATE stories SET like_count = :like_count, updated_at = :updated_at WHERE id = :id', ['like_count' => $likeCount, 'updated_at' => gmdate(DATE_ATOM), 'id' => $storyId]);
            jsonResponse(200, ['liked' => false, 'likeCount' => $likeCount]);
        }

        $db->execute('INSERT INTO story_likes (story_id, user_id, liked_at) VALUES (:story_id, :user_id, :liked_at)', ['story_id' => $storyId, 'user_id' => $userId, 'liked_at' => gmdate(DATE_ATOM)]);
        $likeCount = (int) $db->fetchOne('SELECT COUNT(*) AS count FROM story_likes WHERE story_id = :story_id', ['story_id' => $storyId])['count'];
        $db->execute('UPDATE stories SET like_count = :like_count, updated_at = :updated_at WHERE id = :id', ['like_count' => $likeCount, 'updated_at' => gmdate(DATE_ATOM), 'id' => $storyId]);

        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id LIMIT 1', ['id' => $storyId]);
        if ($story && (string) $story['author_id'] !== $userId) {
            $notificationId = uuid();
            $db->execute(
                'INSERT INTO notifications (id, recipient_id, actor_id, actor_name, type, story_id, comment_id, is_read, created_at)
                 VALUES (:id, :recipient_id, :actor_id, :actor_name, :type, :story_id, NULL, 0, :created_at)',
                ['id' => $notificationId, 'recipient_id' => $story['author_id'], 'actor_id' => $userId, 'actor_name' => $currentUser['displayName'], 'type' => 'like', 'story_id' => $storyId, 'created_at' => gmdate(DATE_ATOM)]
            );
        }

        Backup::save('story_likes', ['storyId' => $storyId, 'userId' => $userId], $storyId . '_' . $userId, 'like');
        jsonResponse(200, ['liked' => true, 'likeCount' => $likeCount]);
    }

    if ($route === 'stories' && $resourceId && $segments[2] === 'comments' && $method === 'POST') {
        $text = trim((string) ($payload['text'] ?? ''));
        if ($text === '' || mb_strlen($text) > 1000) {
            throw new InvalidArgumentException('Comment text is required and max 1000 chars.', 422);
        }

        $commentId = uuid();
        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id AND deleted_at IS NULL LIMIT 1', ['id' => $resourceId]);
        if (!$story) {
            throw new RuntimeException('Story not found.', 404);
        }

        $db->execute(
            'INSERT INTO story_comments (id, story_id, author_id, author_name, author_photo, text, parent_id, like_count, created_at, is_deleted, deleted_at)
             VALUES (:id, :story_id, :author_id, :author_name, :author_photo, :text, :parent_id, 0, :created_at, 0, NULL)',
            ['id' => $commentId, 'story_id' => $resourceId, 'author_id' => $userId, 'author_name' => $currentUser['displayName'], 'author_photo' => $currentUser['photoUrl'], 'text' => $text, 'parent_id' => isset($payload['parentId']) ? trim((string) $payload['parentId']) : null, 'created_at' => gmdate(DATE_ATOM)]
        );

        $count = (int) $db->fetchOne('SELECT COUNT(*) AS count FROM story_comments WHERE story_id = :story_id AND is_deleted = 0', ['story_id' => $resourceId])['count'];
        $db->execute('UPDATE stories SET comment_count = :count, updated_at = :updated_at WHERE id = :id', ['count' => $count, 'updated_at' => gmdate(DATE_ATOM), 'id' => $resourceId]);

        if ((string) $story['author_id'] !== $userId) {
            $notificationId = uuid();
            $db->execute(
                'INSERT INTO notifications (id, recipient_id, actor_id, actor_name, type, story_id, comment_id, is_read, created_at)
                 VALUES (:id, :recipient_id, :actor_id, :actor_name, :type, :story_id, :comment_id, 0, :created_at)',
                ['id' => $notificationId, 'recipient_id' => $story['author_id'], 'actor_id' => $userId, 'actor_name' => $currentUser['displayName'], 'type' => 'comment', 'story_id' => $resourceId, 'comment_id' => $commentId, 'created_at' => gmdate(DATE_ATOM)]
            );
        }

        $comment = $db->fetchOne('SELECT * FROM story_comments WHERE id = :id LIMIT 1', ['id' => $commentId]);
        jsonResponse(201, ['message' => 'Comment added successfully.', 'comment' => $comment]);
    }

    if ($route === 'stories' && $resourceId && $segments[2] === 'comments' && $method === 'GET') {
        $comments = $db->fetchAll('SELECT * FROM story_comments WHERE story_id = :story_id ORDER BY created_at DESC', ['story_id' => $resourceId]);
        jsonResponse(200, ['comments' => $comments]);
    }

    if ($route === 'bookmarks' && $method === 'GET') {
        $items = $db->fetchAll('SELECT b.*, s.title, s.author_name FROM bookmarks b LEFT JOIN stories s ON s.id = b.story_id WHERE b.user_id = :user_id ORDER BY b.saved_at DESC', ['user_id' => $userId]);
        jsonResponse(200, ['bookmarks' => $items]);
    }

    if ($route === 'bookmarks' && $method === 'POST') {
        $storyId = trim((string) ($payload['storyId'] ?? ''));
        $db->execute('INSERT OR IGNORE INTO bookmarks (user_id, story_id, saved_at) VALUES (:user_id, :story_id, :saved_at)', ['user_id' => $userId, 'story_id' => $storyId, 'saved_at' => gmdate(DATE_ATOM)]);
        Backup::save('bookmarks', ['storyId' => $storyId, 'userId' => $userId], $storyId . '_' . $userId, 'bookmark');
        jsonResponse(200, ['message' => 'Story saved to bookmarks.']);
    }

    if ($route === 'follow' && $method === 'POST') {
        $targetId = trim((string) ($payload['userId'] ?? ''));
        if ($targetId === $userId) {
            throw new InvalidArgumentException('You cannot follow yourself.', 422);
        }

        $db->execute('INSERT OR IGNORE INTO follows (follower_id, following_id, created_at) VALUES (:follower_id, :following_id, :created_at)', ['follower_id' => $userId, 'following_id' => $targetId, 'created_at' => gmdate(DATE_ATOM)]);
        $db->execute('UPDATE users SET following_count = following_count + 1 WHERE id = :id', ['id' => $userId]);
        $db->execute('UPDATE users SET follower_count = follower_count + 1 WHERE id = :id', ['id' => $targetId]);
        Backup::save('follows', ['followerId' => $userId, 'followingId' => $targetId], $userId . '_' . $targetId, 'follow');
        jsonResponse(200, ['message' => 'Followed successfully.']);
    }

    if ($route === 'follow' && $method === 'DELETE') {
        $targetId = trim((string) ($payload['userId'] ?? ''));
        $db->execute('DELETE FROM follows WHERE follower_id = :follower_id AND following_id = :following_id', ['follower_id' => $userId, 'following_id' => $targetId]);
        $db->execute('UPDATE users SET following_count = MAX(0, following_count - 1) WHERE id = :id', ['id' => $userId]);
        $db->execute('UPDATE users SET follower_count = MAX(0, follower_count - 1) WHERE id = :id', ['id' => $targetId]);
        Backup::save('follows', ['followerId' => $userId, 'followingId' => $targetId], $userId . '_' . $targetId, 'unfollow');
        jsonResponse(200, ['message' => 'Unfollowed successfully.']);
    }

    if ($route === 'notifications' && $method === 'GET') {
        $items = $db->fetchAll('SELECT * FROM notifications WHERE recipient_id = :recipient_id ORDER BY created_at DESC', ['recipient_id' => $userId]);
        jsonResponse(200, ['notifications' => $items]);
    }

    if ($route === 'notifications' && $method === 'POST') {
        $notificationId = trim((string) ($payload['notificationId'] ?? ''));
        $db->execute('UPDATE notifications SET is_read = 1 WHERE id = :id AND recipient_id = :recipient_id', ['id' => $notificationId, 'recipient_id' => $userId]);
        jsonResponse(200, ['message' => 'Notification marked as read.']);
    }

    if ($route === 'search' && $method === 'GET') {
        $query = trim((string) ($_GET['q'] ?? ''));
        if ($query === '') {
            jsonResponse(200, ['stories' => [], 'users' => []]);
        }

        $storyQuery = "%{$query}%";
        $stories = $db->fetchAll(
            'SELECT * FROM stories WHERE deleted_at IS NULL AND is_published = 1 AND (title LIKE :q OR body LIKE :q OR tags LIKE :q) ORDER BY created_at DESC LIMIT 20',
            ['q' => $storyQuery]
        );

        $users = $db->fetchAll(
            'SELECT id, username, display_name, photo_url, bio FROM users WHERE deleted_at IS NULL AND (username LIKE :q OR display_name LIKE :q) ORDER BY username ASC LIMIT 20',
            ['q' => $storyQuery]
        );

        $db->execute('INSERT OR IGNORE INTO recent_searches (id, user_id, query, created_at) VALUES (:id, :user_id, :query, :created_at)', ['id' => uuid(), 'user_id' => $userId, 'query' => $query, 'created_at' => gmdate(DATE_ATOM)]);
        jsonResponse(200, ['stories' => $stories, 'users' => $users]);
    }

    if ($route === 'reports' && $method === 'POST') {
        $targetType = trim((string) ($payload['targetType'] ?? ''));
        $targetId = trim((string) ($payload['targetId'] ?? ''));
        $reason = trim((string) ($payload['reason'] ?? ''));
        $note = trim((string) ($payload['note'] ?? ''));

        if (!in_array($targetType, ['story', 'comment', 'user'], true)) {
            throw new InvalidArgumentException('Invalid target type.', 422);
        }

        if ($reason === '') {
            throw new InvalidArgumentException('Report reason is required.', 422);
        }

        if (Validation::containsProfanity($reason) || Validation::containsProfanity($note)) {
            throw new InvalidArgumentException('Report text contains unsupported language.', 422);
        }

        $reportId = uuid();
        $db->execute(
            'INSERT INTO reports (id, reporter_id, target_type, target_id, reason, note, status, created_at)
             VALUES (:id, :reporter_id, :target_type, :target_id, :reason, :note, :status, :created_at)',
            ['id' => $reportId, 'reporter_id' => $userId, 'target_type' => $targetType, 'target_id' => $targetId, 'reason' => $reason, 'note' => $note, 'status' => 'open', 'created_at' => gmdate(DATE_ATOM)]
        );

        Backup::save('reports', ['id' => $reportId, 'reporterId' => $userId, 'targetType' => $targetType, 'targetId' => $targetId], $reportId, 'report');
        jsonResponse(201, ['message' => 'Report submitted successfully.']);
    }

    if ($route === 'users' && $method === 'DELETE' && $resourceId) {
        if ((string) $currentUser['id'] !== $resourceId && $currentUser['email'] !== 'admin@example.com') {
            throw new RuntimeException('Forbidden.', 403);
        }
        $target = $db->fetchOne('SELECT * FROM users WHERE id = :id AND deleted_at IS NULL LIMIT 1', ['id' => $resourceId]);
        if (!$target) {
            throw new RuntimeException('User not found.', 404);
        }
        $db->execute('UPDATE users SET deleted_at = :deleted_at, updated_at = :updated_at WHERE id = :id', ['deleted_at' => gmdate(DATE_ATOM), 'updated_at' => gmdate(DATE_ATOM), 'id' => $resourceId]);
        Backup::save('users', ['id' => $resourceId, 'deletedAt' => gmdate(DATE_ATOM)], $resourceId, 'soft-delete');
        jsonResponse(200, ['message' => 'User account archived successfully.']);
    }

    if ($route === 'stories' && $resourceId && $segments[2] === 'view' && $method === 'POST') {
        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id AND deleted_at IS NULL LIMIT 1', ['id' => $resourceId]);
        if (!$story) {
            throw new RuntimeException('Story not found.', 404);
        }
        $db->execute('UPDATE stories SET view_count = view_count + 1, updated_at = :updated_at WHERE id = :id', ['updated_at' => gmdate(DATE_ATOM), 'id' => $resourceId]);
        jsonResponse(200, ['message' => 'View recorded.']);
    }

    if ($route === 'stories' && $resourceId && $segments[2] === 'trend' && $method === 'GET') {
        $story = $db->fetchOne('SELECT * FROM stories WHERE id = :id AND deleted_at IS NULL LIMIT 1', ['id' => $resourceId]);
        if (!$story) {
            throw new RuntimeException('Story not found.', 404);
        }
        $trendScore = (float) $story['like_count'] * 3 + (float) $story['comment_count'] * 2 + (float) $story['view_count'] * 0.1;
        $db->execute('UPDATE stories SET trend_score = :trend_score, updated_at = :updated_at WHERE id = :id', ['trend_score' => $trendScore, 'updated_at' => gmdate(DATE_ATOM), 'id' => $resourceId]);
        jsonResponse(200, ['trendScore' => $trendScore]);
    }

    if ($route === 'stories' && $method === 'GET' && isset($_GET['trending'])) {
        $limit = min(50, max(1, (int) ($_GET['limit'] ?? 20)));
        $stories = $db->fetchAll('SELECT * FROM stories WHERE deleted_at IS NULL AND is_published = 1 ORDER BY trend_score DESC, created_at DESC LIMIT :limit', ['limit' => $limit]);
        jsonResponse(200, ['stories' => $stories]);
    }

    if ($route === 'stories' && $method === 'GET' && isset($_GET['following'])) {
        $followingRows = $db->fetchAll(
            'SELECT following_id FROM follows WHERE follower_id = :follower_id',
            ['follower_id' => $userId]
        );
        $followingIds = array_column($followingRows, 'following_id');
        if (empty($followingIds)) {
            jsonResponse(200, ['stories' => []]);
        }
        $placeholders = implode(',', array_fill(0, count($followingIds), '?'));
        $stmt = $db->getPdo()->prepare("SELECT * FROM stories WHERE deleted_at IS NULL AND is_published = 1 AND author_id IN ({$placeholders}) ORDER BY created_at DESC LIMIT 50");
        foreach ($followingIds as $i => $fid) {
            $stmt->bindValue($i + 1, $fid);
        }
        $stmt->execute();
        $stories = $stmt->fetchAll();
        jsonResponse(200, ['stories' => $stories]);
    }

    if ($route === 'comments' && $method === 'DELETE' && $resourceId) {
        $comment = $db->fetchOne('SELECT * FROM story_comments WHERE id = :id LIMIT 1', ['id' => $resourceId]);
        if (!$comment) {
            throw new RuntimeException('Comment not found.', 404);
        }
        if ((string) $comment['author_id'] !== $userId && $currentUser['email'] !== 'admin@example.com') {
            throw new RuntimeException('Only the author or admin can delete this comment.', 403);
        }
        $db->execute('UPDATE story_comments SET is_deleted = 1, deleted_at = :deleted_at WHERE id = :id', ['deleted_at' => gmdate(DATE_ATOM), 'id' => $resourceId]);
        Backup::save('story_comments', ['id' => $resourceId, 'deletedAt' => gmdate(DATE_ATOM)], $resourceId, 'soft-delete');
        jsonResponse(200, ['message' => 'Comment deleted.']);
    }

    if ($route === 'follow' && $method === 'GET') {
        $following = $db->fetchAll('SELECT following_id FROM follows WHERE follower_id = :follower_id', ['follower_id' => $userId]);
        $followers = $db->fetchAll('SELECT follower_id FROM follows WHERE following_id = :following_id', ['following_id' => $userId]);
        jsonResponse(200, [
            'following' => array_column($following, 'following_id'),
            'followers' => array_column($followers, 'follower_id'),
        ]);
    }

    if ($route === 'notifications' && $method === 'DELETE') {
        $notificationId = trim((string) ($payload['notificationId'] ?? ''));
        if ($notificationId !== '') {
            $db->execute('DELETE FROM notifications WHERE id = :id AND recipient_id = :recipient_id', ['id' => $notificationId, 'recipient_id' => $userId]);
        } else {
            $db->execute('DELETE FROM notifications WHERE recipient_id = :recipient_id', ['recipient_id' => $userId]);
        }
        jsonResponse(200, ['message' => 'Notifications cleared.']);
    }

    if ($route === 'admin' && $method === 'GET') {
        $admin->requireAdmin($currentUser);
        $dashboard = $admin->dashboard();
        jsonResponse(200, ['dashboard' => $dashboard]);
    }

    if ($route === 'admin' && $segments[1] === 'reports' && $method === 'GET') {
        $admin->requireAdmin($currentUser);
        $reports = $admin->listReports();
        jsonResponse(200, ['reports' => $reports]);
    }

    if ($route === 'admin' && $segments[1] === 'reports' && $method === 'PATCH' && $segments[2] !== null) {
        $admin->requireAdmin($currentUser);
        $status = trim((string) ($payload['status'] ?? ''));
        $updated = $admin->resolveReport($segments[2], $status);
        jsonResponse(200, ['message' => 'Report status updated.', 'report' => $updated]);
    }

    if ($route === 'admin' && $segments[1] === 'users' && $method === 'GET') {
        $admin->requireAdmin($currentUser);
        $users = $db->fetchAll('SELECT id, email, username, display_name, bio, photo_url, follower_count, following_count, story_count, created_at, updated_at, status, deleted_at FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 100');
        jsonResponse(200, ['users' => $users]);
    }

    if ($route === 'admin' && $segments[1] === 'stories' && $method === 'GET') {
        $admin->requireAdmin($currentUser);
        $stories = $db->fetchAll('SELECT * FROM stories WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 100');
        jsonResponse(200, ['stories' => $stories]);
    }

    throw new RuntimeException('Endpoint not found.', 404);
} catch (Throwable $exception) {
    $statusCode = 500;
    if (method_exists($exception, 'getCode') && is_int($exception->getCode()) && $exception->getCode() >= 100) {
        $statusCode = $exception->getCode();
    }
    jsonResponse($statusCode, ['error' => $exception->getMessage()]);
}
