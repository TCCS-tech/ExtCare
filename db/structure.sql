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
-- Name: extcare; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extcare;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: role_enum; Type: TYPE; Schema: extcare; Owner: -
--

CREATE TYPE extcare.role_enum AS ENUM (
    'Admin',
    'User'
);


--
-- Name: attendance_enforce_visit_rules(); Type: FUNCTION; Schema: extcare; Owner: -
--

CREATE FUNCTION extcare.attendance_enforce_visit_rules() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.checkout IS NOT NULL AND NEW.checkout < NEW.checkin THEN
    RAISE EXCEPTION
      'checkout (%) must be at or after checkin (%)',
      NEW.checkout, NEW.checkin
      USING ERRCODE = 'check_violation';
  END IF;

  IF NEW.checkout IS NOT NULL AND
    (NEW.checkout AT TIME ZONE 'America/Los_Angeles')::date <>
    (NEW.checkin AT TIME ZONE 'America/Los_Angeles')::date THEN
    RAISE EXCEPTION
      'checkin (%) and checkout (%) must be on the same Pacific day',
      NEW.checkin, NEW.checkout
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'INSERT' OR NEW.checkout IS NULL THEN
    -- Serialize competing inserts, including visits already checked out.
    PERFORM 1 FROM students WHERE id = NEW.student_id FOR NO KEY UPDATE;

    IF EXISTS (
      SELECT 1
      FROM attendance a
      WHERE a.student_id = NEW.student_id
        AND a.checkout IS NULL
        AND (TG_OP = 'INSERT' OR a.id IS DISTINCT FROM OLD.id)
    ) THEN
      RAISE EXCEPTION
        'student % already has an open checkin; checkout first',
        NEW.student_id
        USING ERRCODE = 'exclusion_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: extcare; Owner: -
--

CREATE TABLE extcare.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: attendance; Type: TABLE; Schema: extcare; Owner: -
--

CREATE TABLE extcare.attendance (
    id bigint NOT NULL,
    student_id bigint NOT NULL,
    day date NOT NULL,
    checkin timestamp with time zone NOT NULL,
    checkout timestamp with time zone,
    checkin_by bigint NOT NULL,
    pickup_notes text,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT attendance_checkout_after_checkin CHECK (((checkout IS NULL) OR (checkout >= checkin)))
);


--
-- Name: attendance_id_seq; Type: SEQUENCE; Schema: extcare; Owner: -
--

CREATE SEQUENCE extcare.attendance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attendance_id_seq; Type: SEQUENCE OWNED BY; Schema: extcare; Owner: -
--

ALTER SEQUENCE extcare.attendance_id_seq OWNED BY extcare.attendance.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: extcare; Owner: -
--

CREATE TABLE extcare.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: extcare; Owner: -
--

CREATE TABLE extcare.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: extcare; Owner: -
--

CREATE SEQUENCE extcare.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: extcare; Owner: -
--

ALTER SEQUENCE extcare.sessions_id_seq OWNED BY extcare.sessions.id;


--
-- Name: students; Type: TABLE; Schema: extcare; Owner: -
--

CREATE TABLE extcare.students (
    id bigint NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    grade integer NOT NULL,
    blackbaud_id text NOT NULL,
    student_id text NOT NULL,
    guardians text[] DEFAULT '{}'::text[] NOT NULL,
    notes text,
    staff boolean DEFAULT false NOT NULL,
    prepaid_am boolean DEFAULT false NOT NULL,
    prepaid_pm boolean DEFAULT false NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: students_id_seq; Type: SEQUENCE; Schema: extcare; Owner: -
--

CREATE SEQUENCE extcare.students_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: students_id_seq; Type: SEQUENCE OWNED BY; Schema: extcare; Owner: -
--

ALTER SEQUENCE extcare.students_id_seq OWNED BY extcare.students.id;


--
-- Name: users; Type: TABLE; Schema: extcare; Owner: -
--

CREATE TABLE extcare.users (
    id bigint NOT NULL,
    email text NOT NULL,
    role extcare.role_enum DEFAULT 'User'::extcare.role_enum NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: extcare; Owner: -
--

CREATE SEQUENCE extcare.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: extcare; Owner: -
--

ALTER SEQUENCE extcare.users_id_seq OWNED BY extcare.users.id;


--
-- Name: attendance id; Type: DEFAULT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.attendance ALTER COLUMN id SET DEFAULT nextval('extcare.attendance_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.sessions ALTER COLUMN id SET DEFAULT nextval('extcare.sessions_id_seq'::regclass);


--
-- Name: students id; Type: DEFAULT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.students ALTER COLUMN id SET DEFAULT nextval('extcare.students_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.users ALTER COLUMN id SET DEFAULT nextval('extcare.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: attendance_one_open_per_student; Type: INDEX; Schema: extcare; Owner: -
--

CREATE UNIQUE INDEX attendance_one_open_per_student ON extcare.attendance USING btree (student_id) WHERE (checkout IS NULL);


--
-- Name: index_attendance_on_checkin_by; Type: INDEX; Schema: extcare; Owner: -
--

CREATE INDEX index_attendance_on_checkin_by ON extcare.attendance USING btree (checkin_by);


--
-- Name: index_attendance_on_student_id; Type: INDEX; Schema: extcare; Owner: -
--

CREATE INDEX index_attendance_on_student_id ON extcare.attendance USING btree (student_id);


--
-- Name: index_attendance_on_student_id_and_day; Type: INDEX; Schema: extcare; Owner: -
--

CREATE INDEX index_attendance_on_student_id_and_day ON extcare.attendance USING btree (student_id, day);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: extcare; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON extcare.sessions USING btree (user_id);


--
-- Name: index_students_on_blackbaud_id_and_student_id; Type: INDEX; Schema: extcare; Owner: -
--

CREATE UNIQUE INDEX index_students_on_blackbaud_id_and_student_id ON extcare.students USING btree (blackbaud_id, student_id);


--
-- Name: index_students_on_first_name; Type: INDEX; Schema: extcare; Owner: -
--

CREATE INDEX index_students_on_first_name ON extcare.students USING btree (first_name);


--
-- Name: index_students_on_grade; Type: INDEX; Schema: extcare; Owner: -
--

CREATE INDEX index_students_on_grade ON extcare.students USING btree (grade);


--
-- Name: index_students_on_last_name; Type: INDEX; Schema: extcare; Owner: -
--

CREATE INDEX index_students_on_last_name ON extcare.students USING btree (last_name);


--
-- Name: index_users_on_email; Type: INDEX; Schema: extcare; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON extcare.users USING btree (email);


--
-- Name: attendance attendance_enforce_visit_rules; Type: TRIGGER; Schema: extcare; Owner: -
--

CREATE TRIGGER attendance_enforce_visit_rules BEFORE INSERT OR UPDATE OF student_id, day, checkin, checkout ON extcare.attendance FOR EACH ROW EXECUTE FUNCTION extcare.attendance_enforce_visit_rules();


--
-- Name: attendance fk_rails_0e61de1732; Type: FK CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.attendance
    ADD CONSTRAINT fk_rails_0e61de1732 FOREIGN KEY (checkin_by) REFERENCES extcare.users(id) ON DELETE RESTRICT;


--
-- Name: attendance fk_rails_385396d64f; Type: FK CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.attendance
    ADD CONSTRAINT fk_rails_385396d64f FOREIGN KEY (student_id) REFERENCES extcare.students(id) ON DELETE RESTRICT;


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: extcare; Owner: -
--

ALTER TABLE ONLY extcare.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES extcare.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO extcare,public;

INSERT INTO "schema_migrations" (version) VALUES
('20260923012633'),
('20260923012632'),
('20260923012631'),
('20260923012630'),
('20260923010000');

