# Incident diagnosis — `ActiveRecord::RecordNotUnique` on `traces`

> **STATUS: UNVERIFIED — needs DB / deploy confirmation.**
> This document is a *diagnosis only*. No code or schema change is shipped, because
> the root cause cannot be confirmed from the source tree alone and the live database
> for this product is not reachable from the investigation environment (see
> "Why this is unverified" below). Do **not** merge a migration based on this note
> until a human runs the confirmation commands.

## Alert

| Field | Value |
|---|---|
| Event | `error` (new error) |
| Product | Observability (`reflex`) |
| Error class | `ActiveRecord::RecordNotUnique` |
| Message | `PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_traces_on_trac…"` |
| Fingerprint | `3378714c3ef78f3d` |
| Error group | `754d8678-1a6e-4033-a409-d74eca4dfa32` |
| Project | `6e130615-079b-440a-b7f9-c4c48b42f52f` |
| Occurred | 2026-06-16 18:47:27 UTC |
| Environment | production |
| reflex_url | https://reflex.brainzlab.ai/error_groups/754d8678-1a6e-4033-a409-d74eca4dfa32 |

The constraint name is truncated in the payload (`index_traces_on_trac…`); it is almost
certainly `index_traces_on_trace_id` (or a similar single/compound unique index on the
`traces` table).

## What was checked

1. **Vault DB credentials** — `vault_db_query action=list_credentials` returns:
   `amplifica-db-ro, bite-db-ro, browq-db-ro, doiteveryday-db-ro, nexus-db-ro,
   propi-db-ro, sinfiltro-db-ro, sondea-db-ro, synapse-db-ro`.
   There is **no `observability-db-ro` (or `reflex-db-ro`) credential**, so the live
   Observability database schema and rows could not be inspected.

2. **The `traces` table does not exist in this repository at HEAD.**
   - Models present: `application_record, assistant_chat, assistant_message,
     error_event, error_group, project`. There is no `Trace` model.
   - Migrations present only create: `projects`, `error_groups`, `error_events`
     (TimescaleDB hypertable), `assistant_chats`/`assistant_messages`, plus
     `solid_queue_*` infra tables. No migration creates a `traces` table or an
     `index_traces_on_*` unique index.
   - `db/structure.sql` (this app uses `schema_format = :sql`) contains no `traces`
     table.
   - The only `trace`-related code is **W3C Trace-Context correlation** in
     `app/controllers/api/v1/browser_controller.rb` (parsing `traceparent` /
     `trace_id` into event *context*); it does not persist to a `traces` table.

3. **Reflex / recall lookups** — the error group `754d8678…` and fingerprint
   `3378714c…` are not retrievable through the reflex MCP from this environment
   ("Error not found"; the API key is scoped to a different project). A search for
   `ActiveRecord::RecordNotUnique` returned 0 results, and recall logs contain no
   `traces` / `UniqueViolation` / `duplicate key` entries.

## Why this is unverified

Two independent blockers, either of which alone forbids a confident code fix:

- **No database access for this product.** A `RecordNotUnique` is a *runtime data /
  schema* condition. Without `observability-db-ro` (or equivalent) we cannot confirm
  the real `traces` schema, the exact unique index, or whether duplicate rows exist.
- **The referenced table is not in this codebase.** Writing a migration or model for
  a `traces` table that does not appear in `reflex` would be a plausible-but-wrong
  change. The alert almost certainly does **not** originate from `reflex`'s own
  persistence layer.

## Most likely root cause (hypotheses, ranked)

**H1 — Misrouted alert: the error comes from an upstream app, not from reflex.**
`reflex` is an error *aggregator*: applications across the fleet POST their exceptions
to it. A `traces` table with a unique index is consistent with a tracing/APM or
ingestion path in *another* service (the one whose project is
`6e130615-079b-440a-b7f9-c4c48b42f52f`), which reported this exception **into** reflex.
The fix would belong in that upstream service, not here. The classic cause of
`duplicate key … traces_on_trace_id` is a **non-idempotent insert on an at-least-once
ingestion path** — a collector re-delivers the same `trace_id` (retry / replay), or two
workers `find_or_create`/`INSERT` the same `trace_id` concurrently (check-then-insert
TOCTOU) with no `ON CONFLICT` handling.

**H2 — Migration / deploy drift on the Observability DB.** If a `traces` table *was*
added to the live DB by a migration not present on this branch (or the branch that is
deployed differs from `main`), the running code could be inserting duplicates. This is
a deploy-state problem, not a source bug, and is exactly why DB confirmation is required.

> Note: `reflex`'s own ingestion (`app/services/error_processor.rb`) uses
> `find_or_create_by!(fingerprint:)`, which is the *same class* of TOCTOU footgun —
> two concurrent events with one fingerprint can both miss the `SELECT` and both
> `INSERT`, raising `RecordNotUnique`. It is **not** the table in this alert, but it is
> the canonical pattern behind the symptom and the template for the eventual fix.

## Confirm before fixing — exact commands for a human

1. **Find which app/DB owns the `traces` table** (run against the project that owns
   `6e130615-079b-440a-b7f9-c4c48b42f52f`; identify it via the platform/reflex admin):

   ```sql
   -- Does this table/index exist, and what is the exact unique constraint?
   SELECT indexname, indexdef
   FROM pg_indexes
   WHERE tablename = 'traces';
   -- Expect to see the constraint truncated in the alert, e.g. index_traces_on_trace_id.
   ```

2. **Confirm it is a duplicate-insert (not a stale sequence):**

   ```sql
   SELECT trace_id, COUNT(*)
   FROM traces
   GROUP BY trace_id
   HAVING COUNT(*) > 1
   ORDER BY 2 DESC
   LIMIT 20;
   ```

3. **Locate the failing insert in the owning repo:**

   ```bash
   grep -rnE "Trace\.(create|insert|new)|\.traces\.(create|build)|insert_all.*traces" app/ lib/
   # Look for create!/save without ON CONFLICT, or find_or_create_by on trace_id.
   ```

4. **If it is reflex itself** (only if step 1 shows reflex's DB owns `traces`),
   reconcile schema/deploy drift first:

   ```bash
   bin/rails db:migrate:status     # is a traces migration pending / unexpectedly applied?
   git log --oneline -- db/         # does deployed code match this branch?
   ```

## The fix that would follow (once H1/H2 is confirmed — do NOT apply blind)

- **If it is a non-idempotent ingest (most likely):** make the write idempotent in the
  owning service. Prefer DB-level conflict handling over check-then-insert:

  ```ruby
  # Bulk path
  Trace.insert_all(rows, unique_by: :trace_id)          # ON CONFLICT DO NOTHING

  # Single-record path — race-safe alternative to find_or_create_by!
  Trace.create_or_find_by!(trace_id: trace_id) { |t| ... }
  # or rescue + retry the find:
  begin
    Trace.create!(trace_id: trace_id, ...)
  rescue ActiveRecord::RecordNotUnique
    Trace.find_by!(trace_id: trace_id)
  end
  ```

  (The same hardening should be applied to `ErrorProcessor#find_or_create_group` in
  this repo as defence-in-depth, tracked separately — it is not the cause of *this*
  alert.)

- **If it is schema/deploy drift (H2):** redeploy the correct revision and/or run the
  pending migrations on the Observability DB; no new code change.

## Recommended operational follow-ups

- Provision an `observability-db-ro` Vault credential so future RecordNotUnique /
  schema alerts on this product can actually be verified.
- Verify the reflex MCP API key used by incident response can read the
  Observability project (`6e130615…`); right now its error groups are not visible,
  which blocks pulling the backtrace that would pin down the owning service.
