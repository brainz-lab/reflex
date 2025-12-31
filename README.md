# Reflex

Error tracking with instant reaction for Rails apps.

[![CI](https://github.com/brainz-lab/reflex/actions/workflows/ci.yml/badge.svg)](https://github.com/brainz-lab/reflex/actions/workflows/ci.yml)
[![CodeQL](https://github.com/brainz-lab/reflex/actions/workflows/codeql.yml/badge.svg)](https://github.com/brainz-lab/reflex/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/brainz-lab/reflex/graph/badge.svg)](https://codecov.io/gh/brainz-lab/reflex)
[![Docker](https://github.com/brainz-lab/reflex/actions/workflows/docker.yml/badge.svg)](https://github.com/brainz-lab/reflex/actions/workflows/docker.yml)
[![Docker Hub](https://img.shields.io/docker/v/brainzllc/reflex?label=Docker%20Hub)](https://hub.docker.com/r/brainzllc/reflex)
[![Docs](https://img.shields.io/badge/docs-brainzlab.ai-orange)](https://docs.brainzlab.ai/products/reflex/overview)
[![License: OSAaSy](https://img.shields.io/badge/License-OSAaSy-blue.svg)](LICENSE)

## Overview

Reflex captures and groups errors from your Rails applications, giving you instant visibility into production issues.

- **Smart Grouping** - Errors grouped by fingerprint, not just class
- **Rich Context** - Full backtrace, request data, user info
- **Real-time Alerts** - Instant notifications via Slack, email, webhooks
- **Issue Tracking** - Resolve, ignore, mute with regression detection
- **MCP Integration** - AI-powered error analysis and resolution

## Quick Start

### With Docker

```bash
docker pull brainzllc/reflex:latest
# or
docker pull ghcr.io/brainz-lab/reflex:latest

docker run -d \
  -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host:5432/reflex \
  -e REDIS_URL=redis://host:6379/2 \
  -e RAILS_MASTER_KEY=your-master-key \
  brainzllc/reflex:latest
```

### Install SDK

```ruby
# Gemfile
gem 'brainzlab'
```

```ruby
# config/initializers/brainzlab.rb
BrainzLab.configure do |config|
  config.reflex_key = ENV['REFLEX_API_KEY']
end
```

### Capture Errors

```ruby
# Automatic capture with middleware (Rails)
# Errors are automatically captured!

# Manual capture
begin
  risky_operation
rescue => e
  BrainzLab::Reflex.capture(e, user: current_user, context: { order_id: order.id })
end

# With extra context
BrainzLab::Reflex.set_context(user: current_user)
BrainzLab::Reflex.set_tags(environment: "production", region: "us-east-1")
```

## Tech Stack

- **Ruby** 3.4.7
- **Rails** 8.1
- **PostgreSQL** 16 with JSONB
- **Redis** 7
- **Hotwire** (Turbo + Stimulus)
- **Tailwind CSS**
- **Solid Queue** / **Solid Cache** / **Solid Cable**

## Error Grouping

Errors are grouped by fingerprint generated from:

1. **Error class** - `NoMethodError`, `ActiveRecord::RecordNotFound`
2. **File path** - First frame's file location
3. **Function name** - Method where error occurred
4. **Normalized message** - IDs and numbers replaced with placeholders

This means similar errors are grouped together, even if the specific IDs differ.

## Error States

| Status | Description |
|--------|-------------|
| `unresolved` | New or recurring error |
| `resolved` | Fixed, will reopen if it recurs |
| `ignored` | Won't trigger alerts |
| `muted` | Temporarily silenced |

## API Endpoints

### Ingest
- `POST /api/v1/errors` - Report single error
- `POST /api/v1/errors/batch` - Batch report

### Query
- `GET /api/v1/errors` - List error groups
- `GET /api/v1/errors/:id` - Get error details with events

### Actions
- `POST /api/v1/errors/:id/resolve` - Mark resolved
- `POST /api/v1/errors/:id/ignore` - Ignore error
- `POST /api/v1/errors/:id/unresolve` - Reopen error
- `POST /api/v1/errors/:id/mute` - Mute temporarily

### MCP
- `GET /mcp/tools` - List MCP tools
- `POST /mcp/tools/:name` - Call MCP tool
- `POST /mcp/rpc` - JSON-RPC endpoint

## MCP Tools

| Tool | Description |
|------|-------------|
| `reflex_list` | List errors (filter by status, sort) |
| `reflex_show` | Get error details + backtrace |
| `reflex_resolve` | Mark error as resolved |
| `reflex_ignore` | Ignore an error |
| `reflex_unresolve` | Reopen a resolved error |
| `reflex_stats` | Error statistics and trends |
| `reflex_search` | Search by class, user, commit |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection | Yes |
| `REDIS_URL` | Redis connection | Yes |
| `RAILS_MASTER_KEY` | Rails credentials | Yes |
| `BRAINZLAB_PLATFORM_URL` | Platform URL for auth | Yes |
| `SERVICE_KEY` | Internal service key | Yes |
| `SLACK_WEBHOOK_URL` | Slack notifications | No |

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
  "timestamp": "2024-12-21T10:00:00Z",
  "request": {
    "method": "POST",
    "path": "/users",
    "params": {"name": "John"},
    "headers": {"User-Agent": "..."}
  },
  "user": {
    "id": "user_123",
    "email": "john@example.com"
  },
  "context": {
    "order_id": "order_456"
  },
  "tags": {
    "region": "us-east-1"
  }
}
```

## Testing

```bash
bin/rails test              # Unit tests
bin/rails test:system       # System tests
bin/rubocop                 # Linting
```

## Documentation

Full documentation: [docs.brainzlab.ai/products/reflex](https://docs.brainzlab.ai/products/reflex/overview)

## Related

- [brainzlab-ruby](https://github.com/brainz-lab/brainzlab-ruby) - Ruby SDK
- [Recall](https://github.com/brainz-lab/recall) - Structured logging
- [Pulse](https://github.com/brainz-lab/pulse) - APM
- [Stack](https://github.com/brainz-lab/stack) - Self-hosted deployment

## Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

Thanks to all our contributors! See [all-contributors](https://allcontributors.org) for how to add yourself.


## License

MIT
