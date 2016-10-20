<#
.SYNOPSIS  Query vCenter Server Database (VCDB) for its
           current usage of the Core, Alarm, Events & Stats table
.DESCRIPTION Script that performs SQL Query against a VCDB running
            on a vPostgres DB
.NOTES  Author:    William Lam - @lamw
.NOTES  Site:      www.virtuallyghetto.com
.NOTES  Reference: http://www.virtuallyghetto.com/2016/10/how-to-check-the-size-of-your-config-seat-data-in-the-vcdb-in-vpostgres.html
.PARAMETER dbServer
   VCDB Server
.PARAMETER dbName
   VCDB Instance Name
.PARAMETER dbUsername
   VCDB Username
.PARAMETER dbPassword
   VCDB Password
.EXAMPLE
  Run the script locally on the Microsoft SQL Server hosting the vCenter Server Database
  Get-VCDBUsagevPostgres -dbServer vcenter60-1.primp-industries.com -dbName VCDB -dbUser vc -dbPass "VMware1!"
#>

Function Get-VCDBUsagevPostgres{
    param(
          [string]$dbServer,
          [string]$dbName,
          [string]$dbUser,
          [string]$dbPass
         )

         $query = @"
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
"@

    $conn = New-Object System.Data.Odbc.OdbcConnection
    $conn.ConnectionString = "Driver={PostgreSQL UNICODE(x64)};Server=$dbServer;Port=5432;Database=$dbName;Uid=$dbUser;Pwd=$dbPass;"
    $conn.open()
    $cmd = New-object System.Data.Odbc.OdbcCommand($query,$conn)
    $ds = New-Object system.Data.DataSet
    (New-Object system.Data.odbc.odbcDataAdapter($cmd)).fill($ds) | out-null
    $conn.close()
    $ds.Tables[0]
}

# Please replace variables your own VCDB details
$dbServer = "vcenter60-1.primp-industries.com"
$dbInstance = "VCDB"
$dbUsername = "vc"
$dbPassword = "ezbo3wrMqkJB6{7t"

Get-VCDBUsagevPostgres $dbServer $dbInstance $dbUsername $dbPassword
