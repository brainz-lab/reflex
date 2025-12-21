# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Reflex by Brainz Lab

Error tracking with instant reaction for Rails apps. Second product in the Brainz Lab suite.

**Domain**: reflex.brainzlab.ai

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          REFLEX (Rails 8)                        │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Dashboard   │  │     API      │  │  MCP Server  │           │
│  │  (Hotwire)   │  │  (JSON API)  │  │   (Ruby)     │           │
│  │ /dashboard/* │  │  /api/v1/*   │  │   /mcp/*     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                           │                  │                   │
│                           ▼                  ▼                   │
│              ┌─────────────────────────────────────┐            │
│              │       PostgreSQL + JSONB            │            │
│              └─────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              ▲
            ┌─────────────────┴─────────────────┐
            │                                    │
    ┌───────┴───────┐                  ┌────────┴────────┐
    │  SDK (Gem)    │                  │   Claude/AI     │
    │ brainzlab-sdk │                  │  (Uses MCP)     │
    └───────────────┘                  └─────────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL with JSONB
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (real-time errors)
- **MCP Server**: Ruby (integrated into Rails)

## Common Commands

```bash
# Development
bin/rails server
bin/rails console
bin/rails db:migrate

# Testing
bin/rails test
bin/rails test test/models/error_group_test.rb  # single file

# Docker (from brainzlab root)
docker-compose --profile reflex up
docker-compose exec reflex bin/rails db:migrate

# Database
bin/rails db:create db:migrate
bin/rails db:seed
```

## Key Models

- **Project**: Links to Platform via `platform_project_id`
- **ErrorGroup**: Groups similar errors by fingerprint. Has status (unresolved, resolved, ignored, muted)
- **ErrorEvent**: Individual error occurrences with JSONB context (backtrace, request, user, etc.)

## Error Processing Flow

1. SDK/client sends error to `POST /api/v1/errors`
2. `ErrorProcessor` generates fingerprint via `FingerprintGenerator`
3. Finds or creates `ErrorGroup` by fingerprint
4. Creates `ErrorEvent` with full context
5. Updates group stats (event_count, last_seen_at)
6. Broadcasts to `ErrorsChannel` for real-time updates
7. Schedules notification if needed

## MCP Tools

| Tool | Description |
|------|-------------|
| `reflex_list` | List errors (filter by status, sort by recent/frequent) |
| `reflex_show` | Get error details + backtrace |
| `reflex_resolve` | Mark error as resolved |
| `reflex_ignore` | Ignore an error |
| `reflex_unresolve` | Reopen a resolved error |
| `reflex_stats` | Error statistics and trends |
| `reflex_search` | Search by class, user, commit |

## API Endpoints

**Ingest**:
- `POST /api/v1/errors` - Ingest single error
- `POST /api/v1/errors/batch` - Batch ingest

**Query**:
- `GET /api/v1/errors` - List errors
- `GET /api/v1/errors/:id` - Get error details
- `POST /api/v1/errors/:id/resolve` - Resolve error
- `POST /api/v1/errors/:id/ignore` - Ignore error
- `POST /api/v1/errors/:id/unresolve` - Unresolve error

**MCP**:
- `GET /mcp/tools` - List tools
- `POST /mcp/tools/:name` - Call tool
- `POST /mcp/rpc` - JSON-RPC protocol

Authentication: `Authorization: Bearer <key>` or `X-API-Key: <key>`

## Error Payload Format

```json
{
  "error_class": "NoMethodError",
  "message": "undefined method `foo' for nil:NilClass",
  "backtrace": [
    "app/models/user.rb:42:in `save'",
    "app/controllers/users_controller.rb:23:in `create'"
  ],
  "environment": "production",
  "commit": "abc123",
  "request": {
    "method": "POST",
    "path": "/users",
    "params": {"name": "John"}
  },
  "user": {
    "id": "user_123",
    "email": "john@example.com"
  },
  "context": {},
  "tags": {},
  "timestamp": "2024-12-21T10:00:00Z"
}
```

## Fingerprinting

Errors are grouped by fingerprint generated from:
1. Error class (e.g., `NoMethodError`)
2. File path from first backtrace frame
3. Function name from first backtrace frame
4. Normalized message (numbers replaced with `N`, IDs with `ID`)

## Design Principles

- Clean, minimal UI like Anthropic/Claude
- Use Hotwire for real-time updates (live errors via ActionCable)
- JSONB for flexible structured data
- GIN indexes for fast JSONB queries
- API-first design (dashboard sits on top of API)
