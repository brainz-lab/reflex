# Incident Diagnosis — `ActiveRecord::RecordNotUnique` on `traces` (fingerprint `36c3077f812d85b2`)

> **STATUS: UNVERIFIED — needs DB/deploy confirmation.**
> This is a **diagnosis-only** document. No code change is shipped because the
> root cause **cannot be verified from this repository**, and there is **no
> read-only database credential for the Observability product** available to
> confirm the live schema/data. See "Why no fix is shipped" below.

## Event

| Field | Value |
|---|---|
| Event | `error` |
| Product | Observability (this repo: `reflex`) |
| Fingerprint | `36c3077f812d85b2` |
| Occurred | 2026-06-16 16:05:34 UTC |
| Error class | `ActiveRecord::RecordNotUnique` |
| Message | `PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "index_traces_on_trac..."` (truncated) |
| project_id | `6e130615-079b-440a-b7f9-c4c48b42f52f` |
| reflex_url | https://reflex.brainzlab.ai/error_groups/09077b70-887b-4471-a9d9-6aed39f11fac |

The error reports a **duplicate-key violation** on a unique index whose name
begins `index_traces_on_trace…` (most plausibly `index_traces_on_trace_id`
or `index_traces_on_trace_id_and_span_id`) on a `traces` table.

## What was verified

1. **The `traces` table does not exist in this codebase.**
   This app uses `config.active_record.schema_format = :sql`
   (`config/application.rb:55`); the authoritative schema is `db/structure.sql`.
   Its tables are: `error_events`, `error_groups`, `projects`,
   `schema_migrations`, `ar_internal_metadata`, and `solid_queue_*`.
   There is **no `traces` table** and **no `index_traces_on_trace*` index**.
   - No migration in `db/migrate/` creates `traces`.
   - No `Trace`/`Span` model exists (`app/models/` = `error_event`, `error_group`,
     `project`, `assistant_chat`, `assistant_message`).
   - `trace_id` / `traceparent` appear only as request-correlation fields stored
     in the `error_events.context` JSONB (`app/controllers/api/v1/browser_controller.rb`)
     — not as a relational table.

2. **The reflex error group is not retrievable.** `reflex_show` / `reflex_events`
   for `09077b70-887b-4471-a9d9-6aed39f11fac` return "Error not found", and a
   7-day `reflex_stats` / `reflex_search "RecordNotUnique"` returns **no** traces
   or RecordNotUnique error group — the only known groups are unrelated
   (`empresas`/enrichment template errors, a `solid_cache_entries` missing-table
   error). The traces error is not present in the reflex instance reachable here.

3. **No way to verify the live database.** Vault `vault_db_query
   action:list_credentials` exposes only:
   `amplifica-db-ro, bite-db-ro, browq-db-ro, doiteveryday-db-ro, nexus-db-ro,
   propi-db-ro, sinfiltro-db-ro, sondea-db-ro, synapse-db-ro`.
   **There is no `observability-db-ro` (or `reflex-db-ro`) credential.** The live
   Observability schema/data therefore cannot be inspected from this VM.

## Why no fix is shipped

The erroring object (`traces` table + `index_traces_on_trace…`) is **absent from
this repository**, and the live Observability database **cannot be queried** (no
credential). Writing a new migration or `Trace` model here would be a
plausible-but-wrong fix: it would either create a table the application does not
use, or mask real schema drift. Per incident-response policy, a code change is
only shipped when the root cause is verified in code or DB. Neither is possible
here, so this is recorded as a diagnosis only.

## Most likely root cause (hypotheses, ranked)

**H1 — Misattributed / cross-service error (most likely).**
The error originates in a different service that owns a `traces` table (a
distributed-tracing / span-ingest path) and was attributed to the Observability
product via reflex. The `traces` concept does not belong to `reflex` as it exists
on `main`. This is consistent with the reflex MCP being unable to find the error
group at all.

**H2 — Schema/deploy drift (DB ahead of repo).**
If the live Observability deployment genuinely has a `traces` table (e.g. an
unmerged or environment-only tracing feature), then this is a classic
**non-idempotent insert on an at-least-once ingest path**: the same
`trace_id` (± `span_id`) is delivered/retried more than once and a plain
`INSERT`/`create!` raises `RecordNotUnique` on the second write. Trace/span
ingestion is inherently duplicate-prone (retried jobs, concurrent workers,
at-least-once queues), so the insert must be idempotent.

> Note: the existing reflex ingest already follows the idempotent pattern this
> would need — `ErrorProcessor#find_or_create_group` uses
> `find_or_create_by!(fingerprint:)` (`app/services/error_processor.rb:31-43`).
> Even that is race-prone under concurrency and ideally pairs with a rescue of
> `ActiveRecord::RecordNotUnique` + retry. Whatever service owns `traces` needs
> the same treatment.

## Commands a human with DB/deploy access should run to confirm

```bash
# 1. Does the traces table/index actually exist in the live Observability DB?
psql "$OBSERVABILITY_DATABASE_URL" -c '\d+ traces'
psql "$OBSERVABILITY_DATABASE_URL" -c '\di index_traces*'

# 2. Get the full (untruncated) constraint name + columns it covers.
psql "$OBSERVABILITY_DATABASE_URL" -c \
  "SELECT indexname, indexdef FROM pg_indexes WHERE indexname LIKE 'index_traces_on_trace%';"

# 3. Is the deployed schema ahead of this repo? Compare applied migrations.
psql "$OBSERVABILITY_DATABASE_URL" -c \
  'SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 20;'
#   ...vs. `ls db/migrate/` in this repo (latest: 20260305200000).

# 4. Identify which service/project actually emitted the error.
#    project_id = 6e130615-079b-440a-b7f9-c4c48b42f52f
#    error_group = 09077b70-887b-4471-a9d9-6aed39f11fac
psql "$REFLEX_DATABASE_URL" -c \
  "SELECT id, project_id, error_class, message, first_seen_at FROM error_groups
   WHERE id = '09077b70-887b-4471-a9d9-6aed39f11fac';"
psql "$REFLEX_DATABASE_URL" -c \
  "SELECT id, name, platform_project_id FROM projects
   WHERE id = '6e130615-079b-440a-b7f9-c4c48b42f52f';"

# 5. Find the repo that actually defines the traces index, then fix it there.
#    (search the owning service, NOT reflex):
git grep -n 'index_traces_on_trace' || rg 'create_table .*traces|index_traces_on_trace'
```

## The fix that would follow (once H2 is confirmed in the owning service)

Make the trace/span insert **idempotent** in the service that actually owns the
`traces` table — do **not** add a migration to `reflex`:

- Prefer an upsert: `Trace.upsert(attrs, unique_by: :index_traces_on_trace_id)`
  or `insert_all([...], unique_by: ...)`, or raw `INSERT ... ON CONFLICT
  (trace_id[, span_id]) DO NOTHING/DO UPDATE`.
- Or `find_or_create_by!`/`create_or_find_by!` keyed on the unique columns.
- Or rescue `ActiveRecord::RecordNotUnique` around the insert and treat the
  duplicate as a successful no-op (safe under at-least-once delivery / job
  retries / concurrent workers).

If H1 is confirmed instead (cross-service misattribution), re-route the alert to
the correct product and close this against reflex.
