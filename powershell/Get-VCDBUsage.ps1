<#
.SYNOPSIS  Query vCenter Server Database (VCDB) for its
           current usage of the Core, Alarm, Events & Stats table
.DESCRIPTION Script that performs SQL Query against a VCDB running either
             MSSQL & Oracle and collects current usage data for the
             following tables Core, Alarm, Events & Stats table. In
             Addition, if you wish to use the VCSA Migration Tool, the script
             can also calculate the estimated downtime required for either
             migration Option 1 or 2.
.NOTES  Author:    William Lam - @lamw
.NOTES  Site:      www.virtuallyghetto.com
.NOTES  Reference: http://www.virtuallyghetto.com/2016/09/how-to-check-the-size-of-your-config-stats-events-alarms-tasks-seat-data-in-the-vcdb.html
.PARAMETER dbType
  mssql or oracle
.PARAMETER connectionType
  local (mssql) and remote (mssql or oracle)
.PARAMETER dbServer
   VCDB Server
.PARAMETER dbPort
   VCDB Server Port
.PARAMETER dbUsername
   VCDB Username
.PARAMETER dbPassword
   VCDB Password
.PARAMETER dbInstance
   VCDB Instance Name
.PARAMETER estimate_migration_type
   option1 or option2 for those looking to calculate Windows VC to VCSA Migration (vSphere 6.0 U2m only)
.EXAMPLE
  Run the script locally on the Microsoft SQL Server hosting the vCenter Server Database
  Get-VCDBUsage -dbType mssql -connectionType local
.EXAMPLE
  Run the script remotely on the Microsoft SQL Server hosting the vCenter Server Database
  Get-VCDBUsage -dbType mssql -connectionType local -dbServer sql.primp-industries.com -dbPort 1433 -dbInstance VCDB -dbUsername sa -dbPassword VMware1!
.EXAMPLE
  Run the script remotely on the Microsoft SQL Server hosting the vCenter Server Database & calculate VCSA migration downtime w/option1
  Get-VCDBUsage -dbType mssql -connectionType local -dbServer sql.primp-industries.com -dbPort 1433 -dbInstance VCDB -dbUsername sa -dbPassword VMware1! -migration_type option1
.EXAMPLE
  Run the script remotely to connect to Oracle Sever hosting the vCenter Server Database
  Get-VCDBUsage -dbType oracle -connectionType remote -dbServer oracle.primp-industries.com -dbPort 1521 -dbInstance VCDB -dbUsername vpxuser -dbPassword VMware1!
#>

function UpdateGitHubStats ([string] $csv_stats)
{
    #
    # github token test in psh
    #

    $encoded_token = "YmUxMzZlZWI4ZGI1ZTY3NmJjMGQ1ZmI1MDhjOTYzZGExZDEyNDkzZA=="
    $github_token = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded_token))
    $github_repository = "https://api.github.com/repos/migrate2vcsa/stats/contents/vcsadb.csv?access_token=$github_token"

    $HttpRes = ""

    # Fetch the current file content/commit data (GET)
    try {
        $HttpRes = Invoke-RestMethod -Uri $github_repository -Method "GET" -ContentType "application/json"
    }
    catch {
        Write-Host -ForegroundColor Red "Error connecting to $github_repository"
        Write-Host -ForegroundColor Red $_.Exception.Message
    }


    # Decode base64 text
    $content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($HttpRes.content))

    # Append any new stuff to the current text file
    $newcontent = $content + "$csv_stats`n"

    # Encode back to base64
    $encoded_content = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($newcontent))

    # Fetch commit sha
    $sha = $HttpRes.sha

    # Generate json response
    $json = @"
    {
        "sha": "$sha",
        "content": "$encoded_content",
        "message": "Updated file",
        "committer": {
            "name" : "vS0ciety",
            "email" : "migratetovcsa@gmail.com"
        }
    }
"@

    # Create the commit request (PUT)
    try {
        $HttpRes = Invoke-RestMethod -Uri $github_repository -Method "PUT" -Body $json -ContentType "application/json"
    }
    catch {
        Write-Host -ForegroundColor Red "Error connecting to $github_repository"
        Write-Host -ForegroundColor Red $_.Exception.Message
    }
}

Function Get-VCDBMigrationTime {
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Double]$alarmData,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Double]$coreData,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Double]$eventData,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Double]$statData,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$migration_type
    )

    # Sum up total size of the selected migration option
    switch($migration_type) {
        option1 {$VCDBSize=[math]::Round(($coreData + $alarmData),2);break}
        option2 {$VCDBSize=[math]::Round(($coreData + $alarmData + $eventData + $statData),2);break}
    }

    # Formulas extracted from excel spreadsheet from https://kb.vmware.com/kb/2146420
    $H5 = [math]::round(1.62*[math]::pow(2.5, [math]::Log($VCDBSize/75,2)) + (5.47-1.62)/75*$VCDBSize,2)
    $H7 = [math]::round(1.62*[math]::pow(2.5, [math]::Log($VCDBSize/75,2)) + (3.93-1.62)/75*$VCDBSize,2)
    $H6 = $H5 - $H7

    # Calculate timings
    $totalTimeHours = [math]::floor($H5)
    $totalTimeMinutes = [math]::round($H5 - $totalTimeHours,2)*60
    $exportTimeHours = [math]::floor($H6)
    $exportTimeMinutes = [math]::round($H6 - $exportTimeHours,2)*60
    $importTimeHours = [math]::floor($H7)
    $importtTimeminutes = [math]::round($H7 - $importTimeHours,2)*60

    # Return nice description string of selected migration option
    switch($migration_type) {
        option1 { $migrationDescription = "(Core + Alarm = " + $VCDBSize + " GB)";break}
        option2 { $migrationDescription = "(Core + Alarm + Event + Stat = " + $VCDBSize + " GB)";break}
    }

    Write-Host -ForegroundColor Yellow "`nvCenter Server Migration Estimates for"$migration_type $migrationDescription"`n"
    Write-Host "Total  Time :" $totalTimeHours "Hours" $totalTimeMinutes "Minutes"
    Write-Host "Export Time :" $exportTimeHours "Hours" $exportTimeMinutes "Minutes"
    Write-Host "Import Time :" $importTimeHours "Hours" $importtTimeminutes "Minutes`n"
}

Function Get-VCDBUsage {
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$dbType,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$connectionType,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$dbServer,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$dbPort,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$dbUsername,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$dbPassword,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$dbInstance,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$estimate_migration_type
    )

    $mssql_vcdb_usage_query = @"
use $dbInstance;
select tabletype, sum(rowcounts) as rowcounts,
       sum(spc.usedspaceKB)/1024.0 as usedspaceMB
from
    (select
        s.name as schemaname,
        t.name as tablename,
        p.rows as rowcounts,
        sum(a.used_pages) * 8 as usedspaceKB,
        case
            when t.name like 'VPX_ALARM%' then 'Alarm'
            when t.name like 'VPX_EVENT%' then 'ET'
            when t.name like 'VPX_TASK%' then 'ET'
            when t.name like 'VPX_HIST_STAT%' then 'Stats'
            when t.name = 'VPX_STAT_COUNTER' then 'Stats'
            when t.name = 'VPX_TOPN%' then 'Stats'
            else 'Core'
        end as tabletype
    from
        sys.tables t
    inner join
        sys.schemas s on s.schema_id = t.schema_id
    inner join
        sys.indexes i on t.object_id = i.object_id
    inner join
        sys.partitions p on i.object_id = p.object_id and i.index_id = p.index_id
    inner join
        sys.allocation_units a on p.partition_id = a.container_id
    where
        t.name not like 'dt%'
        and t.is_ms_shipped = 0
        and i.object_id >= 255
    group by
        t.name, s.name, p.rows) as spc

group by tabletype;
"@

    $oracle_vcdb_usage_query = @"
SELECT tabletype,
       SUM(CASE rn WHEN 1 THEN row_cnt ELSE 0 END) AS rowcount,
       ROUND(SUM(sized)/(1024*1024)) usedspaceMB
 FROM (
      SELECT
            CASE
               WHEN segment_name LIKE '%ALARM%' THEN 'Alarm'
               WHEN segment_name LIKE '%EVENT%' THEN 'ET'
               WHEN segment_name LIKE '%TASK%' THEN 'ET'
               WHEN segment_name LIKE '%HIST_STAT%' THEN 'Stats'
               WHEN segment_name LIKE 'VPX_TOPN%' THEN 'Stats'
               ELSE 'Core'
            END AS tabletype,
            row_cnt,
            sized ,
            ROW_NUMBER () OVER (PARTITION BY table_name ORDER BY segment_name) AS rn
       FROM (
            SELECT
                  t.table_name, t.table_name segment_name,
                  t.NUM_ROWS AS row_cnt, s.bytes AS sized
             FROM user_segments s
             JOIN user_tables t ON s.segment_name = t.table_name AND s.segment_type = 'TABLE'
             UNION ALL
            SELECT
                  ti.table_name,i.index_name, ti.NUM_ROWS,s.bytes
             FROM user_segments s
             JOIN user_indexes i ON s.segment_name = i.index_name AND s.segment_type = 'INDEX'
             JOIN user_tables ti ON i.table_name = ti.table_name) table_index ) type_cnt_size
GROUP BY tabletype
"@

    $oracle_odbc_dll_path = "C:\Oracle\odp.net\managed\common\Oracle.ManagedDataAccess.dll"

    Function Run-VCDBMSSQLQuery {

        Function Run-LocalMSSQLQuery {
            Write-Host -ForegroundColor Green "`nRunning Local MSSQL VCDB Usage Query"

            # Check whether Invoke-Sqlcmd cmdlet exists
            if( (Get-Command "Invoke-Sqlcmd" -errorAction SilentlyContinue -CommandType Cmdlet) -eq $null) {
               Write-Host -ForegroundColor Red "Invoke-Sqlcmd cmdlet does not exists on this system, you will need to install SQL Tools or run remotely with DB credentials`n"
               exit
            }

            try {
                $results = Invoke-Sqlcmd -Query $mssql_vcdb_usage_query
            }
            catch { Write-Host -ForegroundColor Red "Unable to connect to the SQL Server. Its possible the SQL Server is not configured to allow remote connections`n"; exit }

            foreach ($result in $results) {
                switch($result.tabletype) {
                    Alarm { $alarm_usage=$result.usedspaceMB; $alarm_rows=$result.rowcounts; break}
                    Core { $core_usage=$result.usedspaceMB; $core_rows=$result.rowcounts; break}
                    ET { $event_usage=$result.usedspaceMB; $event_rows=$result.rowcounts; break}
                    Stats { $stat_usage=$result.usedspaceMB; $stat_rows=$result.rowcounts; break}
                }
            }

            return ($alarm_usage,$core_usage,$event_usage,$stat_usage,$alarm_rows,$core_rows,$event_rows,$stat_rows)
        }

        Function Run-RemoteMSSQLQuery {
            if($dbServer -eq $null -or $dbPort -eq $null -or $dbInstance -eq $null -or $dbUsername -eq $null -or $dbPassword -eq $null) {
                Write-host -ForegroundColor Red "One or more parameters is missing for the remote MSSQL Query option`n"
                exit
            }

            Write-Host -ForegroundColor Green "`nRunning Remote MSSQL VCDB Usage Query"

            $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
            $SqlConnection.ConnectionString = "Server = $dbServer, $dbPort; Database = $dbInstance; User ID = $dbUsername; Password = $dbPassword;"

            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandText = $mssql_vcdb_usage_query
            $SqlCmd.Connection = $SqlConnection

            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd

            try {
                $DataSet = New-Object System.Data.DataSet
                $numRecords = $SqlAdapter.Fill($DataSet)
            } catch { Write-Host -ForegroundColor Red "Unable to connect and execute query on the SQL Server. Its possible the SQL Server is not configured to allow remote connections`n"; exit }

            $SqlConnection.Close()

            foreach ($result in $DataSet.Tables[0]) {
                switch($result.tabletype) {
                    Alarm { $alarm_usage=$result.usedspaceMB; $alarm_rows=$result.rowcounts; break}
                    Core { $core_usage=$result.usedspaceMB; $core_rows=$result.rowcounts; break}
                    ET { $event_usage=$result.usedspaceMB; $event_rows=$result.rowcounts; break}
                    Stats { $stat_usage=$result.usedspaceMB; $stat_rows=$result.rowcounts; break}
                }
            }

            return ($alarm_usage,$core_usage,$event_usage,$stat_usage,$alarm_rows,$core_rows,$event_rows,$stat_rows)
        }

        switch($connectionType) {
            local { Run-LocalMSSQLQuery;break}
            remote { Run-RemoteMSSQLQuery;break}
        }
    }

    Function Run-VCDBOracleQuery {
        if($dbServer -eq $null -or $dbPort -eq $null -or $dbInstance -eq $null -or $dbUsername -eq $null -or $dbPassword -eq $null) {
            Write-host -ForegroundColor Red "One or more parameters is missing for the remote Oracle Query option`n"
            exit
        }

        Write-Host -ForegroundColor Green "`nRunning Remote Oracle VCDB Usage Query"

        if(Test-Path "$oracle_odbc_dll_path") {
            Add-Type -Path "$oracle_odbc_dll_path"

            $connectionString="Data Source = (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$dbserver)(PORT=$dbport))(CONNECT_DATA=(SERVICE_NAME=$dbinstance)));User Id=$dbusername;Password=$dbpassword;"

            $connection = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($connectionString)

            try {
                $connection.open()
                $command=$connection.CreateCommand()
                $command.CommandText=$query
                $reader=$command.ExecuteReader()
            } catch { Write-Host -ForegroundColor Red "Unable to connect to Oracle DB. Ensure your connection info is correct and system allows for remote connections`n"; exit }

            while ($reader.Read()) {
                $table_name = $reader.getValue(0)
                $table_rows = $reader.getValue(1)
                $table_size = $reader.getValue(2)
                switch($table_name) {
                    Alarm { $alarm_usage=$table_size; $alarm_rows=$table_rows; break}
                    Core { $core_usage=$table_size; $core_rows=$table_rows; break}
                    ET { $event_usage=$table_size; $event_rows=$table_rows; break}
                    Stats { $stat_usage=$table_size; $stat_rows=$table_rows; break}
                }
            }
            $connection.Close()

        } else {
            Write-Host -ForegroundColor Red "Unable to find Oracle ODBC DLL which has been defined in the following path: $oracle_odbc_dll_path"
            exit
        }
        return ($alarm_usage,$core_usage,$event_usage,$stat_usage,$alarm_rows,$core_rows,$event_rows,$stat_rows)
    }

    # Run selected DB query and return 4 expected tables from VCDB
    ($alarmData,$coreData,$eventData,$statData,$alarm_rows,$core_rows,$event_rows,$stat_rows) = (0,0,0,0,0,0,0,0)
    switch($dbType) {
        mssql { ($alarmData,$coreData,$eventData,$statData,$alarm_rows,$core_rows,$event_rows,$stat_rows) = Run-VCDBMSSQLQuery; break }
        oracle { ($alarmData,$coreData,$eventData,$statData,$alarm_rows,$core_rows,$event_rows,$stat_rows) = Run-VCDBOracleQuery; break }
        default { Write-Host "mssql or oracle are the only valid dbType options" }
    }

    # Convert data from MB to GB
    $coreData = [math]::Round(($coreData*1024*1024)/1GB,2)
    $alarmData = [math]::Round(($alarmData*1024*1024)/1GB,2)
    $eventData = [math]::Round(($eventData*1024*1024)/1GB,2)
    $statData = [math]::Round(($statData*1024*1024)/1GB,2)

    Write-Host "`nCore Data :"$coreData" GB (rows:"$core_rows")"
    Write-Host "Alarm Data:"$alarmData" GB (rows:"$alarm_rows")"
    Write-Host "Event Data:"$eventData" GB (rows:"$event_rows")"
    Write-Host "Stat Data :"$statData" GB (rows:"$stat_rows")"

    # If user wants VCSA migration estimates, run the additional calculation
    if($estimate_migration_type -eq "option1" -or $estimate_migration_type -eq "option2") {
        Get-VCDBMigrationTime -alarmData $alarmData -coreData $coreData -eventData $eventData -statData $statData -migration_type $estimate_migration_type
    }

    Write-Host -ForegroundColor Magenta `
    "`nWould you like to be able to compare your VCDB Stats with others? `
If so, when prompted, type yes and only the size & # of rows will `
be sent to https://github.com/migrate2vcsa for further processing`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -eq "Y" -or $answer -eq "y") {
        UpdateGitHubStats("$dbType,$alarmData,$coreData,$eventData,$statData,$alarm_rows,$core_rows,$event_rows,$stat_rows")
    }
}

# Please replace variables your own VCDB details
$dbType = "mssql"
$connectionType = "remote"
$dbServer = "sql.primp-industries.com"
$dbPort = "1433"
$dbInstance = "VCDB"
$dbUsername = "sa"
$dbPassword = "VMware1!"

Get-VCDBUsage -connectionType $connectionType -dbType $dbType -dbServer $dbServer -dbPort $dbPort -dbInstance $dbInstance -dbUsername $dbUsername -dbPassword $dbPassword
