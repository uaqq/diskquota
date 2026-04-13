-- Test to check duplication at the output of show_fast_role_tablespace_quota_view

CREATE DATABASE bfv_show_fast_role_tablespace_view;

\c bfv_show_fast_role_tablespace_view
CREATE EXTENSION diskquota;

CREATE ROLE test_duplicate_role;
ALTER ROLE test_duplicate_role WITH SUPERUSER;

select diskquota.init_table_size_table();

BEGIN;

SELECT diskquota.set_role_tablespace_quota('test_duplicate_role', 'pg_default', '100MB');
SET ROLE test_duplicate_role;
CREATE SCHEMA IF NOT EXISTS test_schema;
CREATE table  table1 AS SELECT generate_series(1,1000) as id;
RESET ROLE;

SELECT role_name FROM diskquota.show_fast_role_tablespace_quota_view
WHERE role_name = 'test_duplicate_role';

select pg_sleep(1);

SELECT role_name FROM diskquota.show_fast_role_tablespace_quota_view
WHERE role_name = 'test_duplicate_role';

drop table table1;

-- repeat all commands in transaction twice, because duplication causes at the second round.

SELECT diskquota.set_role_tablespace_quota('test_duplicate_role', 'pg_default', '100MB');
SET ROLE test_duplicate_role;
CREATE SCHEMA IF NOT EXISTS test_schema;
CREATE table  table1 AS SELECT generate_series(1,1000) as id;
RESET ROLE;

SELECT role_name FROM diskquota.show_fast_role_tablespace_quota_view
WHERE role_name = 'test_duplicate_role';

select pg_sleep(1);

SELECT role_name FROM diskquota.show_fast_role_tablespace_quota_view
WHERE role_name = 'test_duplicate_role';

drop table table1;

ROLLBACK;

-- cleanup
DROP ROLE test_duplicate_role;
DROP EXTENSION diskquota;
\c contrib_regression
DROP DATABASE bfv_show_fast_role_tablespace_view;
