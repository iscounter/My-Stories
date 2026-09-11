<?php

declare(strict_types=1);

const APP_NAME = 'StoryShare';
const APP_BASE_URL = 'https://zerotech.alwaysdata.net/app/';
const DB_PATH = __DIR__ . '/data/storyshare.db';
const BACKUP_DIR = __DIR__ . '/backup';
const TOKEN_SECRET = 'storyshare-dev-secret-change-me';
const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days

if (!is_dir(__DIR__ . '/data')) {
    mkdir(__DIR__ . '/data', 0775, true);
}

if (!is_dir(BACKUP_DIR)) {
    mkdir(BACKUP_DIR, 0775, true);
}
