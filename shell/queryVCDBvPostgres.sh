#!/bin/bash
# # Author: William Lam
# Site: www.virtuallyghetto.com
# Description: Script to query Config + SEAT Data usage for vPostgres based VCDB
# Reference: http://www.virtuallyghetto.com/2016/10/how-to-check-the-size-of-your-config-seat-data-in-the-vcdb-in-vpostgres.html

VCDB_SQL_QUERY="
SELECT   tabletype,
         sum(reltuples) as rowcount,
         ceil(sum(pg_total_relation_size(oid)) / (1024*1024)) as usedspaceMB
FROM  (
      SELECT   CASE
                  WHEN c.relname LIKE 'vpx_alarm%' THEN 'Alarm'
                  WHEN c.relname LIKE 'vpx_event%' THEN 'ET'
                  WHEN c.relname LIKE 'vpx_task%' THEN 'ET'
                  WHEN c.relname LIKE 'vpx_hist_stat%' THEN 'Stats'
                  WHEN c.relname LIKE 'vpx_topn%' THEN 'Stats'
                  ELSE 'Core'
               END AS tabletype,
               c.reltuples, c.oid
        FROM pg_class C
        LEFT JOIN pg_namespace N
          ON N.oid = C.relnamespace
       WHERE nspname IN ('vc', 'vpx') and relkind in ('r', 't')) t
GROUP BY tabletype;
"

/opt/vmware/vpostgres/current/bin/psql -U postgres -d VCDB -c "${VCDB_SQL_QUERY}"
