# Coeadapt Platform API Reference

> Public API documentation for Career Box integration with the Coeadapt platform.
>
> **Version:** 1.0.0 | **Last Updated:** February 2026

---

## Overview

Career Box connects to the Coeadapt platform API for:

- **Authentication** — Token-based device auth so Career Box can act on behalf of a user
- **Telemetry** — Activity tracking from the local workspace to the cloud
- **Data Sync** — CRUD operations for contacts, achievements, goals, tasks, habits, etc.
- **Subscription Validation** — Verify the user's subscription tier for feature gating

Career Box is designed to work **offline-first**. All cloud API calls are optional and gracefully degrade when the backend is unavailable.

---

## Environments

| Environment | Base URL | Notes |
|-------------|----------|-------|
| **Production** | `https://api.coeadapt.com/api` | Live platform |

---

## Authentication

Career Box uses **Bearer token authentication**. Tokens are generated from the Coeadapt web app and stored securely in the user's OS keyring.

### How It Works

```
1. User logs into https://coeadapt.com
2. User navigates to Settings → Career Box
3. User clicks "Generate Token"
4. Token is displayed ONCE — user copies it
5. User pastes token into Career Box launcher during setup
6. Career Box stores token in OS keyring (never on disk)
7. All API calls include: Authorization: Bearer <token>
```

### Token Details

| Property | Value |
|----------|-------|
| Format | Base64URL-encoded, 43 characters |
| Lifetime | 90 days from generation |
| Storage (backend) | SHA-256 hash only (plaintext never stored) |
| Storage (client) | OS keyring (Windows Credential Manager, macOS Keychain, Linux Secret Service) |
| Revocation | User can revoke from Settings → Career Box → Devices |

### Authentication Header

All authenticated requests must include:

```
Authorization: Bearer <token>
```

### Error Responses

| Status | Meaning | Action |
|--------|---------|--------|
| `401 Unauthorized` | Token missing, invalid, expired, or revoked | Prompt user to re-authenticate |
| `403 Forbidden` | Valid token but insufficient permissions | Check subscription tier |
| `429 Too Many Requests` | Rate limit exceeded | Back off and retry (see `Retry-After` header) |

---

## Rate Limiting

| Endpoint Category | Limit | Window |
|-------------------|-------|--------|
| General API | 100 requests | per minute |
| Telemetry | 20 requests | per minute |
| AI/Expensive operations | 10 requests | per minute |
| Auth endpoints | 20 requests | per 5 minutes |

Rate limit headers are included in every response:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 97
X-RateLimit-Reset: 1708012800
```

When rate limited, the response includes:

```
HTTP/1.1 429 Too Many Requests
Retry-After: 30
```

---

## Response Format

### Success

```json
{
  "success": true,
  "data": { ... }
}
```

Or for simple operations:

```json
{
  "success": true,
  "message": "Operation completed"
}
```

### Error

```json
{
  "success": false,
  "error": "Human-readable error message",
  "code": "ERROR_CODE"
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|------------|-------------|
| `UNAUTHORIZED` | 401 | Missing or invalid auth token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `VALIDATION_ERROR` | 400 | Invalid request body |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error |

---

## Endpoints

### Health & System

#### `GET /api/health`

Check if the Coeadapt API is reachable. **No authentication required.**

**Response:**

```json
{
  "status": "ok",
  "timestamp": "2026-02-14T12:00:00.000Z"
}
```

**Use case:** Career Box should call this on startup and periodically to verify connectivity.

---

### Career Box Device Management

These endpoints manage Career Box device tokens. Called from the **web app** (Clerk session auth), not from Career Box itself.

#### `GET /api/career-box/devices`

List the user's registered Career Box devices.

**Auth:** Web app session (Clerk)

**Response:**

```json
{
  "success": true,
  "devices": [
    {
      "id": "cbt_abc123",
      "deviceName": "My Laptop Career Box",
      "createdAt": "2026-02-01T10:00:00.000Z",
      "lastUsed": "2026-02-14T08:30:00.000Z",
      "expiresAt": "2026-05-02T10:00:00.000Z",
      "isRevoked": false
    }
  ]
}
```

#### `POST /api/career-box/generate-token`

Generate a new Career Box access token. The token is returned **once** in plaintext.

**Auth:** Web app session (Clerk)

**Request:**

```json
{
  "deviceName": "My Laptop Career Box"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceName` | string | Yes | Human-readable name for this device |

**Response:**

```json
{
  "success": true,
  "token": "dGhpcyBpcyBhIHNhbXBsZSB0b2tlbg...",
  "deviceName": "My Laptop Career Box",
  "expiresAt": "2026-05-15T10:00:00.000Z",
  "expiresIn": 7776000,
  "message": "Copy this token now. It will not be shown again."
}
```

| Field | Type | Description |
|-------|------|-------------|
| `token` | string | The access token (Base64URL, shown only once) |
| `expiresAt` | string | ISO 8601 expiration timestamp |
| `expiresIn` | number | Seconds until expiration (90 days = 7,776,000) |

#### `DELETE /api/career-box/devices/:id`

Revoke a Career Box device token. Immediately invalidates all API access for that device.

**Auth:** Web app session (Clerk)

**Response:**

```json
{
  "success": true
}
```

#### `GET /api/career-box/health`

Career Box-specific health check. **No authentication required.**

**Response:**

```json
{
  "status": "ok",
  "timestamp": "2026-02-14T12:00:00.000Z"
}
```

---

### User Profile

#### `GET /api/auth/user`

Get the authenticated user's profile information.

**Auth:** Bearer token

**Response:**

```json
{
  "id": "user_abc123",
  "email": "user@example.com",
  "firstName": "Jane",
  "lastName": "Doe",
  "headline": "Software Engineer",
  "location": "San Francisco, CA"
}
```

---

### Goals

#### `GET /api/goals/me`

Get the user's goals.

**Auth:** Bearer token

**Response:**

```json
{
  "data": [
    {
      "id": "goal_abc123",
      "name": "Master React",
      "description": "Become proficient in React and its ecosystem",
      "status": "active",
      "confidenceRing": 65,
      "createdAt": "2026-01-15T10:00:00.000Z",
      "updatedAt": "2026-02-14T08:00:00.000Z"
    }
  ]
}
```

#### `POST /api/goals`

Create a new goal.

**Auth:** Bearer token

**Request:**

```json
{
  "name": "Master React",
  "description": "Become proficient in React and its ecosystem"
}
```

#### `PATCH /api/goals/:id`

Update a goal.

**Auth:** Bearer token

**Request:**

```json
{
  "name": "Updated goal name",
  "status": "completed"
}
```

#### `DELETE /api/goals/:id`

Delete a goal.

**Auth:** Bearer token

---

### Goal Milestones

#### `GET /api/goals/:goalId/milestones`

Get milestones for a goal.

**Auth:** Bearer token

#### `POST /api/goals/:goalId/milestones`

Create a milestone for a goal.

**Auth:** Bearer token

**Request:**

```json
{
  "title": "Complete React tutorial",
  "description": "Finish the official React tutorial"
}
```

---

### Tasks

#### `GET /api/tasks/me`

Get all tasks for the authenticated user.

**Auth:** Bearer token

**Response:**

```json
{
  "data": [
    {
      "id": "task_abc123",
      "title": "Build a todo app",
      "description": "Create a simple todo application using React",
      "status": "in_progress",
      "planId": "plan_xyz789",
      "dueDate": "2026-02-20T00:00:00.000Z",
      "createdAt": "2026-02-10T10:00:00.000Z"
    }
  ]
}
```

#### `GET /api/tasks/:id`

Get a specific task.

**Auth:** Bearer token

#### `PUT /api/tasks/:id`

Update a task (status, details, etc.).

**Auth:** Bearer token

**Request:**

```json
{
  "status": "complete",
  "completedAt": "2026-02-14T15:30:00.000Z"
}
```

#### `POST /api/tasks/:taskId/evidence`

Submit evidence of task completion (e.g., a repo URL, demo link, or Loom video).

**Auth:** Bearer token

**Request:**

```json
{
  "repoUrl": "https://github.com/user/todo-app",
  "demoUrl": "https://todo-app.vercel.app",
  "loomUrl": "https://loom.com/share/abc123",
  "transcript": "Optional text description of the work done"
}
```

All fields are optional — include whichever evidence types apply.

#### `GET /api/tasks/:taskId/evidence`

Get evidence submitted for a task.

**Auth:** Bearer token

---

### Daily Habits

#### `GET /api/habits`

Get all active habits for the user with today's completion status.

**Auth:** Bearer token

**Response:**

```json
{
  "data": [
    {
      "id": "habit_abc123",
      "name": "Morning coding session",
      "description": "Code for 30 minutes before work",
      "frequency": "daily",
      "activeDays": ["mon", "tue", "wed", "thu", "fri"],
      "currentStreak": 12,
      "longestStreak": 25,
      "completedToday": false,
      "createdAt": "2026-01-01T10:00:00.000Z"
    }
  ]
}
```

#### `GET /api/habits/today`

Get today's habit status (due/done).

**Auth:** Bearer token

#### `POST /api/habits`

Create a new habit.

**Auth:** Bearer token

**Request:**

```json
{
  "name": "Morning coding session",
  "description": "Code for 30 minutes before work",
  "frequency": "daily",
  "activeDays": ["mon", "tue", "wed", "thu", "fri"]
}
```

#### `POST /api/habits/:id/complete`

Mark a habit as completed for today.

**Auth:** Bearer token

#### `GET /api/habits/stats/overview`

Get overall habit statistics (streak counts, completion rates).

**Auth:** Bearer token

---

### Jobs

#### `GET /api/jobs`

Get all active jobs.

**Auth:** Bearer token

#### `GET /api/jobs/discover`

Get personalized job recommendations.

**Auth:** Bearer token

#### `POST /api/jobs/:jobId/bookmark`

Bookmark a job.

**Auth:** Bearer token

#### `DELETE /api/jobs/:jobId/bookmark`

Remove a bookmark.

**Auth:** Bearer token

#### `GET /api/jobs/bookmarks/me`

Get the user's bookmarked jobs.

**Auth:** Bearer token

---

### Plans (Career Roadmaps)

#### `GET /api/plans/me`

Get the user's career plans/roadmaps.

**Auth:** Bearer token

#### `GET /api/plans/:id`

Get a specific plan with details.

**Auth:** Bearer token

#### `GET /api/plans/:planId/tasks`

Get tasks for a specific plan.

**Auth:** Bearer token

---

### Portfolio

#### `GET /api/portfolio/items`

Get the user's portfolio items.

**Auth:** Bearer token

**Response:**

```json
{
  "data": [
    {
      "id": "item_abc123",
      "title": "React Todo App",
      "description": "Full-stack todo application",
      "type": "project",
      "url": "https://github.com/user/todo-app",
      "technologies": ["React", "TypeScript", "Node.js"],
      "createdAt": "2026-02-10T10:00:00.000Z"
    }
  ]
}
```

#### `POST /api/portfolio/items`

Create a portfolio item.

**Auth:** Bearer token

#### `PATCH /api/portfolio/items/:id`

Update a portfolio item.

**Auth:** Bearer token

#### `DELETE /api/portfolio/items/:id`

Delete a portfolio item.

**Auth:** Bearer token

---

### Skills

#### `GET /api/skills/verified`

Get the user's verified skills (skills proven through task evidence).

**Auth:** Bearer token

**Response:**

```json
[
  {
    "skillId": "skill_abc123",
    "skillName": "React",
    "taskCount": 5,
    "avgScore": 87,
    "category": "Technical"
  }
]
```

---

### Market & Career Insights

#### `GET /api/radar/market-fit`

Get skill radar data (skill match, salary potential for target role).

**Auth:** Bearer token

#### `GET /api/radar/skill-deltas`

Get skill gaps and opportunities grouped by type.

**Auth:** Bearer token

---

### Mastery Mode

#### `GET /api/mastery/role-value-map`

Get the user's role value map (for mastery mode users).

**Auth:** Bearer token

---

### Notifications

#### `GET /api/notifications/me`

Get the user's notifications.

**Auth:** Bearer token

#### `PATCH /api/notifications/:id/read`

Mark a notification as read.

**Auth:** Bearer token

---

### Subscription

#### `GET /api/subscription/status`

Check the user's subscription tier and status.

**Auth:** Bearer token

**Response:**

```json
{
  "status": "active",
  "plan": "pro",
  "expiresAt": "2026-03-15T00:00:00.000Z",
  "features": {
    "careerBox": true,
    "aiCoaching": true,
    "marketRadar": true
  }
}
```

**Use case:** Career Box should call this to determine feature access. If the user doesn't have an active subscription with `careerBox: true`, show a message directing them to upgrade.

---

## Planned Endpoints (Not Yet Implemented)

These endpoints are designed for deeper Career Box integration but are **not yet available** on the backend. Career Box should gracefully handle their absence.

### Telemetry

#### `POST /api/career-box/telemetry`

Record workspace activity from the Career Box VM.

**Auth:** Bearer token

**Request:**

```json
{
  "sessionStart": "2026-02-14T08:00:00.000Z",
  "sessionEnd": "2026-02-14T08:30:00.000Z",
  "activityType": "coding",
  "projectName": "todo-app",
  "technologies": ["React", "TypeScript", "Jest"],
  "filesModified": 3,
  "linesOfCode": 145,
  "testsRun": 5,
  "testsPassed": 5,
  "buildSuccess": true,
  "duration": 1800
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sessionStart` | string (ISO 8601) | Yes | When the session started |
| `sessionEnd` | string (ISO 8601) | No | When the session ended (null if still active) |
| `activityType` | string | Yes | One of: `coding`, `learning`, `research`, `project`, `idle` |
| `projectName` | string | No | Name of the project being worked on |
| `technologies` | string[] | No | Technologies detected in the session |
| `filesModified` | number | No | Number of files modified |
| `linesOfCode` | number | No | Lines of code written |
| `testsRun` | number | No | Number of tests executed |
| `testsPassed` | number | No | Number of tests that passed |
| `buildSuccess` | boolean | No | Whether the build succeeded |
| `duration` | number | Yes | Duration in seconds |

### Activity Summary

#### `GET /api/career-box/activity`

Get a summary of Career Box activity for the authenticated user.

**Auth:** Bearer token

**Query params:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `days` | number | 7 | Number of days to look back |

### Sync

#### `POST /api/career-box/sync`

Sync Career Box activity with the user's learning plan.

**Auth:** Bearer token

---

## Integration Guide

### Recommended Call Patterns

**On Career Box startup:**

```
1. GET /api/career-box/health     → Verify connectivity
2. GET /api/subscription/status   → Check feature access
3. GET /api/auth/user             → Load user profile
```

**Periodic sync (every 5 minutes):**

```
1. POST /api/career-box/telemetry → Send activity data
```

**On user request:**

```
GET /api/goals/me                 → Show goals
GET /api/tasks/me                 → Show tasks
GET /api/habits                   → Show habits
POST /api/habits/:id/complete     → Mark habit done
```

### Offline Handling

Career Box should queue API calls when offline and replay them when connectivity is restored:

1. Store telemetry events in a local SQLite database or JSON file
2. On connectivity restore, replay queued telemetry in order
3. Use the `sessionStart`/`sessionEnd` timestamps (not current time) so data is accurate
4. Discard telemetry older than 30 days

### Error Handling

```
if (response.status === 401) {
  // Token expired or revoked
  // Prompt user to generate a new token from the web app
}

if (response.status === 429) {
  // Rate limited — back off
  const retryAfter = response.headers.get('Retry-After');
  await sleep(parseInt(retryAfter) * 1000);
}

if (response.status >= 500) {
  // Server error — retry with exponential backoff
  // Max 3 retries, then queue for later
}

if (!navigator.onLine || fetchError) {
  // Offline — queue the request for later
}
```

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-14 | 1.0.0 | Initial public API reference |

---

## Questions?

- **Career Box issues:** [github.com/alexander-acker/Career-Box/issues](https://github.com/alexander-acker/Career-Box/issues)
- **Coeadapt platform:** [coeadapt.com](https://coeadapt.com)
