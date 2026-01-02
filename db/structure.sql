SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: timescaledb; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;


--
-- Name: EXTENSION timescaledb; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION timescaledb IS 'Enables scalable inserts and complex queries for time-series data (Community Edition)';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: error_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.error_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    error_group_id uuid NOT NULL,
    project_id uuid NOT NULL,
    error_class character varying NOT NULL,
    message text,
    backtrace jsonb DEFAULT '[]'::jsonb,
    environment character varying,
    commit character varying,
    branch character varying,
    release character varying,
    server_name character varying,
    request_id character varying,
    request_method character varying,
    request_url character varying,
    request_path character varying,
    request_params jsonb DEFAULT '{}'::jsonb,
    request_headers jsonb DEFAULT '{}'::jsonb,
    user_id character varying,
    user_email character varying,
    user_data jsonb DEFAULT '{}'::jsonb,
    context jsonb DEFAULT '{}'::jsonb,
    tags jsonb DEFAULT '{}'::jsonb,
    extra jsonb DEFAULT '{}'::jsonb,
    breadcrumbs jsonb DEFAULT '[]'::jsonb,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: error_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.error_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    fingerprint character varying NOT NULL,
    error_class character varying NOT NULL,
    message text,
    file_path character varying,
    line_number integer,
    function_name character varying,
    controller character varying,
    action character varying,
    status character varying DEFAULT 'unresolved'::character varying,
    resolved_at timestamp(6) without time zone,
    resolved_by character varying,
    event_count bigint DEFAULT 0,
    first_seen_at timestamp(6) without time zone,
    last_seen_at timestamp(6) without time zone,
    last_commit character varying,
    last_environment character varying,
    notifications_enabled boolean DEFAULT true,
    last_notified_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform_project_id character varying NOT NULL,
    name character varying,
    environment character varying DEFAULT 'live'::character varying,
    error_count bigint DEFAULT 0,
    event_count bigint DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: error_events error_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_events
    ADD CONSTRAINT error_events_pkey PRIMARY KEY (id, occurred_at);


--
-- Name: error_groups error_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_groups
    ADD CONSTRAINT error_groups_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: error_events_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX error_events_occurred_at_idx ON public.error_events USING btree (occurred_at DESC);


--
-- Name: index_error_events_on_commit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_commit ON public.error_events USING btree (commit);


--
-- Name: index_error_events_on_context; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_context ON public.error_events USING gin (context jsonb_path_ops);


--
-- Name: index_error_events_on_error_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_error_group_id ON public.error_events USING btree (error_group_id);


--
-- Name: index_error_events_on_error_group_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_error_group_id_and_occurred_at ON public.error_events USING btree (error_group_id, occurred_at);


--
-- Name: index_error_events_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_project_id ON public.error_events USING btree (project_id);


--
-- Name: index_error_events_on_project_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_project_id_and_occurred_at ON public.error_events USING btree (project_id, occurred_at);


--
-- Name: index_error_events_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_request_id ON public.error_events USING btree (request_id);


--
-- Name: index_error_events_on_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_tags ON public.error_events USING gin (tags jsonb_path_ops);


--
-- Name: index_error_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_events_on_user_id ON public.error_events USING btree (user_id);


--
-- Name: index_error_groups_on_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_groups_on_fingerprint ON public.error_groups USING btree (fingerprint);


--
-- Name: index_error_groups_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_groups_on_project_id ON public.error_groups USING btree (project_id);


--
-- Name: index_error_groups_on_project_id_and_error_class; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_groups_on_project_id_and_error_class ON public.error_groups USING btree (project_id, error_class);


--
-- Name: index_error_groups_on_project_id_and_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_error_groups_on_project_id_and_fingerprint ON public.error_groups USING btree (project_id, fingerprint);


--
-- Name: index_error_groups_on_project_id_and_last_seen_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_groups_on_project_id_and_last_seen_at ON public.error_groups USING btree (project_id, last_seen_at);


--
-- Name: index_error_groups_on_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_groups_on_project_id_and_status ON public.error_groups USING btree (project_id, status);


--
-- Name: index_projects_on_platform_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_platform_project_id ON public.projects USING btree (platform_project_id);


--
-- Name: error_groups fk_rails_2e1f89a5fa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_groups
    ADD CONSTRAINT fk_rails_2e1f89a5fa FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: error_events fk_rails_3d4243ef94; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_events
    ADD CONSTRAINT fk_rails_3d4243ef94 FOREIGN KEY (error_group_id) REFERENCES public.error_groups(id);


--
-- Name: error_events fk_rails_fb2fa60adf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_events
    ADD CONSTRAINT fk_rails_fb2fa60adf FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

---
--- Drop ts_insert_blocker previously created by pg_dump to avoid pg errors, create_hypertable will re-create it again.
---

DROP TRIGGER IF EXISTS ts_insert_blocker ON public.error_events;
