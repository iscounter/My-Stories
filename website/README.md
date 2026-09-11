# StoryShare Webstore Backend

This folder contains a complete PHP + SQLite backend for the StoryShare app idea without Firebase.

## Included
- PHP auth for registration/login/logout
- SQLite database schema for users, stories, comments, likes, bookmarks, follows, notifications, reports, and searches
- Automatic backup storage in `webstore/backup/`
- REST API endpoints to support the app flow described in the app idea
- Data persistence that never deletes user data permanently; records are soft-deleted and mirrored into backup files

## Important
- The app stores backups in `webstore/backup/` and keeps them even if records are soft-deleted.
- The example domain is set to `https://example.com` in `config.php`.
- Replace the default token secret before production use.

## Base URL
- Local development: `http://localhost/webstore`
- Example production: `https://example.com`

## Auth endpoints
- `POST /webstore/auth/register`
- `POST /webstore/auth/login`
- `POST /webstore/auth/logout`
- `GET /webstore/auth/me`

## User endpoints
- `GET /webstore/users/{id}`
- `PUT /webstore/users/{id}`

## Story endpoints
- `GET /webstore/stories`
- `POST /webstore/stories`
- `GET /webstore/stories/{id}`
- `PUT /webstore/stories/{id}`
- `DELETE /webstore/stories/{id}`
- `POST /webstore/stories/{id}/like`
- `GET /webstore/stories/{id}/comments`
- `POST /webstore/stories/{id}/comments`

## Other endpoints
- `GET /webstore/bookmarks`
- `POST /webstore/bookmarks`
- `POST /webstore/follow`
- `DELETE /webstore/follow`
- `GET /webstore/notifications`
- `POST /webstore/notifications`
- `GET /webstore/search?q=term`
- `POST /webstore/reports`

## Example auth request
```bash
curl -X POST http://localhost/webstore/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@example.com",
    "username": "demo_user",
    "displayName": "Demo User",
    "password": "secret123"
  }'
```

## Example login request
```bash
curl -X POST http://localhost/webstore/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@example.com",
    "password": "secret123"
  }'
```

## Notes
- This is a backend foundation for your app idea and matches the product requirements without Firebase.
- It intentionally avoids deleting user data permanently; it keeps backups and uses soft-delete behavior for operational safety.
