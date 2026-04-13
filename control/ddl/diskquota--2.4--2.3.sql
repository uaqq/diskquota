-- TODO check if worker should not refresh, current lib should be diskquota-2.3.so

-- UDF
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.set_schema_quota(text, text) RETURNS void STRICT AS '$libdir/diskquota-2.3.so' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.set_role_quota(text, text) RETURNS void STRICT AS '$libdir/diskquota-2.3.so' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.init_table_size_table() RETURNS void STRICT AS '$libdir/diskquota-2.3.so' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.diskquota_fetch_table_stat(int4, oid[]) RETURNS setof diskquota.diskquota_active_table_type AS '$libdir/diskquota-2.3.so', 'diskquota_fetch_table_stat' LANGUAGE C VOLATILE;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.set_schema_tablespace_quota(text, text, text) RETURNS void STRICT AS '$libdir/diskquota-2.3.so' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.set_role_tablespace_quota(text, text, text) RETURNS void STRICT AS '$libdir/diskquota-2.3.so' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.set_per_segment_quota(text, float4) RETURNS void STRICT AS '$libdir/diskquota-2.3.so' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.refresh_rejectmap(diskquota.rejectmap_entry[], oid[]) RETURNS void STRICT AS '$libdir/diskquota-2.3.so' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.show_rejectmap() RETURNS setof diskquota.rejectmap_entry_detail AS '$libdir/diskquota-2.3.so', 'show_rejectmap' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.pause() RETURNS void STRICT AS '$libdir/diskquota-2.3.so', 'diskquota_pause' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.resume() RETURNS void STRICT AS '$libdir/diskquota-2.3.so', 'diskquota_resume' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.show_worker_epoch() RETURNS bigint STRICT AS '$libdir/diskquota-2.3.so', 'show_worker_epoch' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.wait_for_worker_new_epoch() RETURNS boolean STRICT AS '$libdir/diskquota-2.3.so', 'wait_for_worker_new_epoch' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.status() RETURNS TABLE ("name" text, "status" text) STRICT AS '$libdir/diskquota-2.3.so', 'diskquota_status' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.show_relation_cache() RETURNS setof diskquota.relation_cache_detail AS '$libdir/diskquota-2.3.so', 'show_relation_cache' LANGUAGE C;

/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.relation_size_local(reltablespace oid, relfilenode oid, relpersistence "char", relstorage "char", relam oid) RETURNS bigint STRICT AS '$libdir/diskquota-2.3.so', 'relation_size_local' LANGUAGE C;
/* ALTER */ CREATE OR REPLACE FUNCTION diskquota.pull_all_table_size(OUT tableid oid, OUT size bigint, OUT segid smallint) RETURNS SETOF RECORD AS '$libdir/diskquota-2.3.so', 'pull_all_table_size' LANGUAGE C;

CREATE VIEW diskquota.show_fast_role_tablespace_quota_view AS
WITH
  default_tablespace AS (
    SELECT dattablespace FROM pg_database
    WHERE datname = current_database()
  ),
  quota_usage AS (
    SELECT
      relowner,
      CASE
        WHEN reltablespace = 0 THEN dattablespace
        ELSE reltablespace
      END AS reltablespace,
      SUM(size) AS total_size
    FROM
      diskquota.table_size,
      diskquota.show_all_relation_view,
      default_tablespace
    WHERE
      tableid = diskquota.show_all_relation_view.oid AND
      segid = -1
    GROUP BY
      relowner,
      reltablespace,
      dattablespace
  ),
  full_quota_config AS (
    SELECT
      primaryOid,
      tablespaceoid,
      quotalimitMB
    FROM
      diskquota.quota_config AS config,
      diskquota.target AS target
    WHERE
      config.targetOid = target.rowId AND
      config.quotaType = target.quotaType AND
      config.quotaType = 3 -- ROLE_TABLESPACE_QUOTA
  )
SELECT
  rolname AS role_name,
  primaryoid AS role_oid,
  spcname AS tablespace_name,
  tablespaceoid AS tablespace_oid,
  quotalimitMB AS quota_in_mb,
  COALESCE(total_size, 0) AS rolsize_tablespace_in_bytes
FROM
  full_quota_config JOIN
  pg_roles ON primaryoid = pg_roles.oid JOIN
  pg_tablespace ON tablespaceoid = pg_tablespace.oid LEFT OUTER JOIN
  quota_usage ON pg_roles.oid = relowner AND pg_tablespace.oid = reltablespace;

-- UDF end
