# StoryShare — Full App Idea & Agent-Ready Spec

Below is a complete product + technical blueprint you can paste to any coding agent. It evolves your current local-only `my_stories` app into a social story-sharing platform.

---

## 1. Product Vision (one paragraph)

**StoryShare** is a social app where people share real-life stories — turning points, decisions, mistakes, small wins, losses, lessons — and readers react with likes, comments, and saves. Think "Instagram for life stories" or "Medium meets a warm community feed." Stories can be public or anonymous. The goal is empathy, discussion, and discovery.

---

## 2. Core Concepts (vocabulary for the agent)

| Term | Meaning |
|---|---|
| **Story** | A post with title + body + category/tags + optional cover image. Has author, likes, comments, saves, views. |
| **Author** | A user. Can be shown as real name or "Anonymous" if `isAnonymous = true`. |
| **Comment** | Text reply on a story. Supports one level of replies. |
| **Like** | One per user per story (toggle). |
| **Bookmark / Save** | Private list of saved stories. |
| **Follow** | User A follows User B to see their new stories in "Following" feed. |
| **Feed** | List of stories. Tabs: **Latest**, **Trending**, **Following**, **Categories**. |
| **Notification** | Like, comment, reply, follow, mention. |
| **Report** | User flags a story/comment for moderation. |

---

## 3. Feature List

### 3.1 MVP (Phase 1 — must work end to end)

**Auth & Profile**
- Email + password sign up / login
- Google sign-in (optional but recommended)
- Forgot password
- Profile: display name, username (unique), bio, avatar image
- Edit profile
- Logout, delete account

**Stories**
- Create story: title, body, category, tags (max 5), optional cover image, anonymous toggle
- Edit / delete own story
- Story detail screen with full body, author card, like/comment/save/share buttons
- Auto-split body into paragraphs (you already do this — keep it)
- Reading time estimate (auto-calculated from word count, ~200 wpm)

**Feed**
- Home feed with tabs: Latest / Trending / Following
- Trending = score from likes + comments + views in last 48h
- Pull-to-refresh, infinite scroll (paginate 20 per page)
- Empty states for each tab

**Engagement**
- Like / unlike (optimistic UI, instant feedback)
- Comment + reply (one nested level)
- Delete own comment
- Save / unsave bookmark
- Share (system share sheet with story link)

**Search & Explore**
- Search stories by title / body / tag
- Search users by name / username
- Category browse screen

**Notifications**
- In-app notification list
- Push notifications (FCM) for like, comment, reply, follow

**Safety**
- Report story / comment
- Block user
- Basic profanity filter on create

### 3.2 Phase 2 — Growth
- Reading progress per story (you already have this locally — sync to cloud)
- Highlights / quotes from a story
- Story series / chapters
- "Write a response" (a story that links to another story)
- Drafts (save without publishing)
- Scheduled publish

### 3.3 Phase 3 — Community
- Topics / communities
- Weekly prompts ("Write about a decision that changed you")
- Direct messages
- Verified authors / badges
- Reading lists / collections

---

## 4. Data Models

### 4.1 Dart models (extend your existing `Story`)

```dart
class UserProfile {
  final String uid;
  final String username;       // unique, lowercase, 3–20 chars
  final String displayName;
  final String bio;
  final String? photoUrl;
  final int followerCount;
  final int followingCount;
  final int storyCount;
  final DateTime createdAt;
}

class Story {
  final String id;
  final String authorId;        // uid
  final String authorName;      // denormalized for fast render
  final String? authorPhoto;
  final bool isAnonymous;
  final String title;           // 3–120 chars
  final String body;            // 50–20,000 chars
  final List<String> paragraphs;// derived, keep your current logic
  final String category;        // from fixed list
  final List<String> tags;      // max 5, lowercase
  final String? coverImageUrl;
  final int readingMinutes;     // auto = (wordCount / 200).ceil()
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Comment {
  final String id;
  final String storyId;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String text;            // 1–1000 chars
  final String? parentId;       // null = top-level
  final int likeCount;
  final DateTime createdAt;
  final bool isDeleted;         // soft delete
}

class AppNotification {
  final String id;
  final String recipientId;
  final String actorId;
  final String actorName;
  final String type;            // like | comment | reply | follow | mention
  final String? storyId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;
}
```

### 4.2 Backend schema (Firebase Firestore)

```
users/{uid}
  username, displayName, bio, photoUrl,
  followerCount, followingCount, storyCount, createdAt

users/{uid}/bookmarks/{storyId}    -> { storyId, savedAt }
users/{uid}/following/{targetUid}  -> { since }

stories/{storyId}
  authorId, authorName, authorPhoto, isAnonymous,
  title, body, paragraphs[], category, tags[],
  coverImageUrl, readingMinutes,
  likeCount, commentCount, viewCount,
  isPublished, createdAt, updatedAt

stories/{storyId}/likes/{uid}      -> { likedAt }
stories/{storyId}/comments/{cid}
  authorId, authorName, authorPhoto, text,
  parentId, likeCount, createdAt, isDeleted

notifications/{uid}/items/{nid}
  actorId, actorName, type, storyId, commentId,
  isRead, createdAt

reports/{reportId}
  reporterId, targetType (story|comment|user),
  targetId, reason, note, status, createdAt
```

**Denormalization rule:** when a story is liked, the client calls a **Cloud Function** `onLikeCreated` that increments `stories/{id}.likeCount` and creates a notification. Do **not** increment counters from the client — race conditions.

### 4.3 Storage (Firebase Storage)
```
avatars/{uid}.jpg
covers/{storyId}.jpg
```

---

## 5. Backend Choice

**Recommended: Firebase**
- Auth (email + Google)
- Firestore (real-time, scalable)
- Storage (images)
- Cloud Functions (counters, notifications, moderation)
- FCM (push)
- Security Rules (per-document access control)

**Alternative: Supabase** if you prefer SQL and open source.

**Do not** use SharedPreferences for social data — it is local-only and cannot be shared between users. Keep it only for: theme, onboarding-seen flag, cached current user uid.

---

## 6. App Architecture (Flutter)

### 6.1 Folder structure
```
lib/
  main.dart
  app.dart
  core/
    constants/       categories, limits, colors
    errors/          AppException, Failure
    utils/           date_format, validators, reading_time
    theme/           app_theme
  models/
    user_profile.dart
    story.dart
    comment.dart
    app_notification.dart
  repositories/
    auth_repository.dart
    user_repository.dart
    story_repository.dart
    comment_repository.dart
    interaction_repository.dart  (likes, bookmarks, follows)
    notification_repository.dart
    storage_repository.dart
  providers/         (Riverpod)
    auth_provider.dart
    feed_provider.dart
    story_provider.dart
    comment_provider.dart
    notification_provider.dart
  screens/
    splash/
    auth/            login, register, forgot_password
    onboarding/
    home/            feed_screen.dart (tabs)
    explore/         search_screen.dart, category_screen.dart
    story/           story_detail_screen.dart
    editor/          story_form_screen.dart
    comments/        comments_sheet.dart
    profile/         profile_screen.dart, edit_profile_screen.dart
    notifications/   notifications_screen.dart
    bookmarks/       bookmarks_screen.dart
    settings/        settings_screen.dart
  widgets/
    story_card.dart
    comment_tile.dart
    user_avatar.dart
    like_button.dart
    empty_state.dart
    error_state.dart
    loading_skeleton.dart
```

### 6.2 State management
Use **Riverpod** (`flutter_riverpod`). Reasons: testable, no BuildContext coupling, good async support (`AsyncNotifier`).

### 6.3 Repository interface pattern
Every repository returns `Future<Result<T>>` where `Result` is `Success<T>` or `Failure`. UI never sees raw exceptions.

---

## 7. Screens & Navigation

```
Splash
  └─ Onboarding (first run)
       └─ Auth (Login / Register / Forgot)
            └─ Root (BottomNav: Home, Explore, Create, Notifications, Profile)
                 ├─ Home      → Feed tabs (Latest / Trending / Following)
                 ├─ Explore   → Search + Categories
                 ├─ Create    → StoryFormScreen
                 ├─ Notifications
                 └─ Profile   → own profile → Edit / Bookmarks / Settings

StoryDetail (pushed from anywhere)
  ├─ Author tap → ProfileScreen(other user)
  ├─ Comment tap → CommentsSheet
  └─ Share → system sheet
```

---

## 8. Functional Working Conditions (acceptance criteria)

These are the rules the agent must implement and test.

### 8.1 Auth
- Email must be valid format, password ≥ 8 chars.
- Username: 3–20 chars, `a-z0-9_`, unique (check before save).
- On register: create `users/{uid}` doc + default profile.
- On logout: clear all providers, pop to Auth.
- On delete account: delete user doc, stories, comments (or mark anonymous).

### 8.2 Story create/edit
- Title: 3–120 chars, required.
- Body: 50–20,000 chars, required, must have ≥ 20 words.
- Category: required, one of fixed list.
- Tags: 0–5, each 2–20 chars, lowercase, no spaces.
- Cover image: optional, max 5 MB, jpg/png.
- Anonymous: if on, hide `authorId` in UI but keep it in DB for moderation.
- Auto-save draft locally every 5 s (SharedPreferences key `draft.story.{id}`).
- On save: write to Firestore, then pop with `true`.
- Edit: only author can edit. Updates `updatedAt`.

### 8.3 Feed
- Latest: order by `createdAt desc`.
- Trending: Cloud Function computes `trendScore = likeCount*3 + commentCount*2 + viewCount*0.1` for last 48h, stored on story as `trendScore`. Feed orders by `trendScore desc`.
- Following: query stories where `authorId in [following list]`, order by `createdAt desc`.
- Pagination: `limit(20)`, cursor = last doc.
- Empty state per tab with CTA.
- Pull-to-refresh reloads first page.

### 8.4 Likes
- Toggle: if `stories/{id}/likes/{uid}` exists → delete (unlike). Else → create (like).
- Optimistic UI: update local count immediately, roll back on error.
- Cloud Function updates `likeCount` and creates notification (skip if liker == author).

### 8.5 Comments
- Text: 1–1000 chars, trimmed.
- Reply: `parentId` = top-level comment id. Only one nesting level.
- Soft delete: set `isDeleted = true`, show "[deleted]" placeholder, keep replies.
- Comment count on story updated by Cloud Function.
- Sort: top-level by `createdAt desc`; replies by `createdAt asc`.

### 8.6 Follow
- Cannot follow yourself.
- Follow writes `users/{me}/following/{them}` and `users/{them}/followers/{me}`, increments counters via Cloud Function.
- Unfollow removes both.

### 8.7 Notifications
- Created for: like, comment, reply, follow, mention.
- Never notify self.
- Mark read on tap.
- Badge count on bottom nav icon.
- FCM push if app in background.

### 8.8 Search
- Debounce 300 ms.
- Search stories: title, body, tags (Firestore `array-contains` + prefix on title).
- Search users: username, displayName.
- Show recent searches (local, max 10).

### 8.9 Moderation
- Report: reason dropdown + optional note → `reports/{id}`.
- Block: user A blocks B → A no longer sees B's stories/comments, and B cannot follow A.
- Profanity filter on create: reject or mask. Maintain local word list.

### 8.10 Error & offline
- Show snackbar on failure with retry.
- Cache last 20 stories in SharedPreferences for offline read.
- Offline writes queue and retry when online (Firestore handles this natively).

### 8.11 Security rules (Firestore)
- `users/{uid}`: read public; write only by owner.
- `stories`: read if `isPublished == true` or requester is author; create if auth; update/delete only by author.
- `comments`: create if auth; update/delete only by author.
- `likes`: create/delete only by owner uid.
- `notifications`: read/write only by recipient.
- `reports`: create if auth; read only by admins.

---

## 9. What Changes From Your Current Code

| Current | New |
|---|---|
| `SharedPreferences` for stories | Firestore for stories; SharedPreferences only for cache/settings |
| Single-user local library | Multi-user social graph |
| `Story` has `isFavorite`, `progressPercent` | Keep these per-user in `users/{uid}/bookmarks` and `users/{uid}/progress/{storyId}` |
| `StoryRepository` reads/writes local JSON | Becomes remote repository; keep same method names where possible (`loadStories`, `upsertStory`, `deleteStory`) so your screens change less |
| `StorySeed` | Replace with "empty feed" + "suggested users to follow" |
| No auth | Auth gate before Home |
| `HomeScreen` shows all stories | Shows feed tabs |

**Migration tip:** Keep `Story.fromJson/toJson` but map to/from Firestore documents. Keep `paragraphs` derived from body so your detail screen does not change.

---

## 10. Build Order (tell the agent to follow this exactly)

1. **Setup**: add `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `flutter_riverpod`, `image_picker`, `cached_network_image`, `share_plus`.
2. **Auth module**: register, login, logout, auth gate. Test end to end.
3. **User profile**: create/edit profile, upload avatar. Test.
4. **Story create/edit/delete** to Firestore. Test with 2 accounts.
5. **Feed**: Latest tab with pagination. Test.
6. **Story detail** + like + comment. Test with 2 accounts.
7. **Bookmarks** + **Following feed**. Test.
8. **Notifications** (in-app first, then FCM). Test.
9. **Search + Explore**. Test.
10. **Report / block / profanity filter**. Test.
11. **Trending** Cloud Function. Test.
12. **Polish**: skeletons, empty states, error states, animations.

Ship after each step. Do not build Phase 2 before Phase 1 is fully working.

---

## 11. One-Block Summary for the Agent

> Build **StoryShare**, a Flutter social app where users share life stories. Use **Firebase** (Auth, Firestore, Storage, FCM, Cloud Functions) and **Riverpod**. Users can register, create a profile, publish stories (title, body, category, tags, optional cover image, anonymous option), like, comment (one level of replies), bookmark, follow, search, and receive notifications. Feed tabs: Latest, Trending, Following. Include report/block and profanity filter. Keep the existing `Story` model but add `authorId`, `likeCount`, `commentCount`, `viewCount`, `tags`, `isAnonymous`, `coverImageUrl`. Move all story storage from SharedPreferences to Firestore; use SharedPreferences only for cache, drafts, and settings. Enforce the validation rules, counters via Cloud Functions, and Firestore security rules listed above. Follow the folder structure and build order in this document.

---

If you want, I can now generate the **actual Dart code** for any single module (e.g. `AuthRepository` + auth screens, or the full Firestore `StoryRepository` with pagination), or the **Firestore security rules** file. Tell me which one to start with.