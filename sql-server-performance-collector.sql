/*
Purpose: Install and run the SQL Server performance collector.
Developed by: Thomas Grubbe Møller of BetterBI ApS.
SQL Server 2017+. Run in master.
Implemented scopes: MissingIndex, WaitStats, ServerResource, FileIo.
Required permission: VIEW SERVER STATE (SQL Server 2019 and earlier), or
VIEW SERVER PERFORMANCE STATE (SQL Server 2022 and later).
*/
USE master;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.PerformanceCollectorRun', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerformanceCollectorRun
    (
        CollectionRunId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PerformanceCollectorRun PRIMARY KEY,
        ServerName nvarchar(128) NOT NULL,
        StartTime datetime2(0) NOT NULL,
        EndTime datetime2(0) NULL,
        SqlServerStartTime datetime2(0) NOT NULL,
        RetentionDays int NOT NULL,
        DatabaseScope nvarchar(max) NOT NULL,
        WaitStatsRows int NULL,
        FileIoRows int NULL,
        ServerResourceRows int NULL,
        MissingIndexRows int NULL,
        Succeeded bit NULL,
        ErrorNumber int NULL,
        ErrorMessage nvarchar(4000) NULL,
        CollectorVersion varchar(20) NOT NULL
    );

    CREATE INDEX IX_PerformanceCollectorRun_StartTime
        ON dbo.PerformanceCollectorRun(StartTime DESC);
END;
GO

IF OBJECT_ID(N'dbo.PerformanceWaitStats', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerformanceWaitStats
    (
        PerformanceWaitStatsId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PerformanceWaitStats PRIMARY KEY,
        CollectionRunId bigint NOT NULL,
        CaptureTime datetime2(0) NOT NULL,
        SqlServerStartTime datetime2(0) NOT NULL,
        ServerName nvarchar(128) NOT NULL,
        WaitType nvarchar(120) NOT NULL,
        WaitingTasksCount bigint NOT NULL,
        WaitTimeMs bigint NOT NULL,
        MaxWaitTimeMs bigint NOT NULL,
        SignalWaitTimeMs bigint NOT NULL,
        CONSTRAINT FK_PerformanceWaitStats_Run FOREIGN KEY(CollectionRunId)
            REFERENCES dbo.PerformanceCollectorRun(CollectionRunId)
    );

    CREATE INDEX IX_PerformanceWaitStats_Analysis
        ON dbo.PerformanceWaitStats(ServerName, WaitType, SqlServerStartTime, CaptureTime)
        INCLUDE(WaitingTasksCount, WaitTimeMs, SignalWaitTimeMs, CollectionRunId);
END;
GO

IF OBJECT_ID(N'dbo.PerformanceFileIo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerformanceFileIo
    (
        PerformanceFileIoId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PerformanceFileIo PRIMARY KEY,
        CollectionRunId bigint NOT NULL,
        CaptureTime datetime2(0) NOT NULL,
        SqlServerStartTime datetime2(0) NOT NULL,
        ServerName nvarchar(128) NOT NULL,
        DatabaseId int NOT NULL,
        DatabaseName sysname NOT NULL,
        FileId int NOT NULL,
        LogicalFileName sysname NOT NULL,
        PhysicalFileName nvarchar(260) NOT NULL,
        FileType nvarchar(60) NOT NULL,
        NumOfReads bigint NOT NULL,
        NumOfBytesRead bigint NOT NULL,
        IoStallReadMs bigint NOT NULL,
        NumOfWrites bigint NOT NULL,
        NumOfBytesWritten bigint NOT NULL,
        IoStallWriteMs bigint NOT NULL,
        IoStallQueuedReadMs bigint NULL,
        IoStallQueuedWriteMs bigint NULL,
        SizeOnDiskBytes bigint NOT NULL,
        CONSTRAINT FK_PerformanceFileIo_Run FOREIGN KEY(CollectionRunId)
            REFERENCES dbo.PerformanceCollectorRun(CollectionRunId)
    );

    CREATE INDEX IX_PerformanceFileIo_Analysis
        ON dbo.PerformanceFileIo(ServerName, DatabaseId, FileId, SqlServerStartTime, CaptureTime)
        INCLUDE(DatabaseName, FileType, NumOfReads, IoStallReadMs, NumOfWrites, IoStallWriteMs, CollectionRunId);
END;
GO

IF OBJECT_ID(N'dbo.PerformanceServerResource', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerformanceServerResource
    (
        PerformanceServerResourceId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PerformanceServerResource PRIMARY KEY,
        CollectionRunId bigint NOT NULL,
        CaptureTime datetime2(0) NOT NULL,
        SqlServerStartTime datetime2(0) NOT NULL,
        ServerName nvarchar(128) NOT NULL,
        TotalPhysicalMemoryKb bigint NULL,
        AvailablePhysicalMemoryKb bigint NULL,
        SystemMemoryState nvarchar(256) NULL,
        SqlPhysicalMemoryInUseKb bigint NULL,
        LockedPagesAllocatedKb bigint NULL,
        LargePageAllocationsKb bigint NULL,
        ProcessPhysicalMemoryLow bit NULL,
        ProcessVirtualMemoryLow bit NULL,
        TotalServerMemoryKb bigint NULL,
        TargetServerMemoryKb bigint NULL,
        MemoryGrantsPending bigint NULL,
        OnlineSchedulers int NULL,
        CurrentTasks bigint NULL,
        RunnableTasks bigint NULL,
        CurrentWorkers bigint NULL,
        ActiveWorkers bigint NULL,
        WorkQueueCount bigint NULL,
        PendingDiskIoCount bigint NULL,
        UserConnections int NULL,
        ActiveRequests int NULL,
        BlockedRequests int NULL,
        CONSTRAINT FK_PerformanceServerResource_Run FOREIGN KEY(CollectionRunId)
            REFERENCES dbo.PerformanceCollectorRun(CollectionRunId)
    );

    CREATE INDEX IX_PerformanceServerResource_Analysis
        ON dbo.PerformanceServerResource(ServerName, SqlServerStartTime, CaptureTime)
        INCLUDE(TotalServerMemoryKb, TargetServerMemoryKb, MemoryGrantsPending, RunnableTasks, PendingDiskIoCount, BlockedRequests, CollectionRunId);
END;
GO

IF OBJECT_ID(N'dbo.PerformanceMissingIndex', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerformanceMissingIndex
    (
        PerformanceMissingIndexId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PerformanceMissingIndex PRIMARY KEY,
        CollectionRunId bigint NOT NULL,
        CaptureTime datetime2(0) NOT NULL,
        SqlServerStartTime datetime2(0) NOT NULL,
        ServerName nvarchar(128) NOT NULL,
        DatabaseId int NOT NULL,
        DatabaseName sysname NOT NULL,
        ObjectId int NOT NULL,
        SchemaName sysname NULL,
        ObjectName sysname NULL,
        IndexHandle int NOT NULL,
        IndexGroupHandle int NOT NULL,
        RecommendationHash binary(32) NOT NULL,
        EqualityColumns nvarchar(4000) NULL,
        InequalityColumns nvarchar(4000) NULL,
        IncludedColumns nvarchar(4000) NULL,
        UniqueCompiles bigint NOT NULL,
        UserSeeks bigint NOT NULL,
        UserScans bigint NOT NULL,
        LastUserSeek datetime NULL,
        LastUserScan datetime NULL,
        AvgTotalUserCost float NOT NULL,
        AvgUserImpact float NOT NULL,
        SystemSeeks bigint NOT NULL,
        SystemScans bigint NOT NULL,
        LastSystemSeek datetime NULL,
        LastSystemScan datetime NULL,
        AvgTotalSystemCost float NOT NULL,
        AvgSystemImpact float NOT NULL,
        ImprovementMeasure AS
            (CONVERT(float, UserSeeks + UserScans) * AvgTotalUserCost * AvgUserImpact / 100.0) PERSISTED,
        CONSTRAINT FK_PerformanceMissingIndex_Run FOREIGN KEY(CollectionRunId)
            REFERENCES dbo.PerformanceCollectorRun(CollectionRunId)
    );

    CREATE INDEX IX_PerformanceMissingIndex_Analysis
        ON dbo.PerformanceMissingIndex
        (ServerName, DatabaseId, ObjectId, RecommendationHash, SqlServerStartTime, CaptureTime)
        INCLUDE(DatabaseName, SchemaName, ObjectName, UserSeeks, UserScans, AvgUserImpact, CollectionRunId);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PerformanceWaitStats') AND name = N'IX_PerformanceWaitStats_CollectionRunId')
    CREATE INDEX IX_PerformanceWaitStats_CollectionRunId ON dbo.PerformanceWaitStats(CollectionRunId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PerformanceFileIo') AND name = N'IX_PerformanceFileIo_CollectionRunId')
    CREATE INDEX IX_PerformanceFileIo_CollectionRunId ON dbo.PerformanceFileIo(CollectionRunId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PerformanceServerResource') AND name = N'IX_PerformanceServerResource_CollectionRunId')
    CREATE INDEX IX_PerformanceServerResource_CollectionRunId ON dbo.PerformanceServerResource(CollectionRunId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.PerformanceMissingIndex') AND name = N'IX_PerformanceMissingIndex_CollectionRunId')
    CREATE INDEX IX_PerformanceMissingIndex_CollectionRunId ON dbo.PerformanceMissingIndex(CollectionRunId);
GO

CREATE OR ALTER PROCEDURE dbo.PerformanceCollector
    @RetentionDays int = 90,
    @Scope nvarchar(100) = N'MissingIndex',
    @Databases nvarchar(max) = N'USER_DATABASES'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RetentionDays < 1
        THROW 50001, 'RetentionDays must be at least 1.', 1;

    DECLARE @SelectedScope table(ScopeName nvarchar(100) PRIMARY KEY);

    INSERT @SelectedScope(ScopeName)
    SELECT DISTINCT UPPER(normalized.ScopeName)
    FROM STRING_SPLIT(COALESCE(@Scope, N''), N',')
    CROSS APPLY
    (
        VALUES
        (
            LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(value, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ')))
        )
    ) AS normalized(ScopeName)
    WHERE normalized.ScopeName <> N'';

    IF NOT EXISTS (SELECT 1 FROM @SelectedScope)
        THROW 50002, 'Scope must include MissingIndex, WaitStats, ServerResource, FileIo, or a comma-separated combination.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @SelectedScope
        WHERE ScopeName NOT IN (N'MISSINGINDEX', N'WAITSTATS', N'SERVERRESOURCE', N'FILEIO')
    )
        THROW 50003, 'Scope contains an unsupported collector scope.', 1;

    IF @Databases IS NULL
        THROW 50004, 'Databases must be USER_DATABASES or a comma-separated database list.', 1;

    DECLARE @NormalizedDatabases nvarchar(max) = UPPER
    (
        LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(@Databases, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ')))
    );

    IF @NormalizedDatabases = N''
        THROW 50004, 'Databases must be USER_DATABASES or a comma-separated database list.', 1;

    DECLARE @DB table(DatabaseId int PRIMARY KEY, DatabaseName sysname NOT NULL);

    IF @NormalizedDatabases = N'USER_DATABASES'
        INSERT @DB(DatabaseId, DatabaseName)
        SELECT database_id, name
        FROM sys.databases
        WHERE database_id > 4
          AND state_desc = N'ONLINE'
          AND source_database_id IS NULL;
    ELSE
        INSERT @DB(DatabaseId, DatabaseName)
        SELECT DISTINCT d.database_id, d.name
        FROM sys.databases AS d
        JOIN
        (
            SELECT normalized.DatabaseName
            FROM STRING_SPLIT(@Databases, N',')
            CROSS APPLY
            (
                VALUES
                (
                    LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(value, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ')))
                )
            ) AS normalized(DatabaseName)
            WHERE normalized.DatabaseName <> N''
        ) AS requested
          ON requested.DatabaseName = d.name COLLATE DATABASE_DEFAULT
        WHERE d.database_id > 4
          AND d.state_desc = N'ONLINE'
          AND d.source_database_id IS NULL;

    DECLARE
        @Version varchar(20) = '1.2.0',
        @StartTime datetime2(0) = SYSDATETIME(),
        @CaptureTime datetime2(0) = SYSDATETIME(),
        @SqlServerStartTime datetime2(0),
        @ServerName nvarchar(128) = CONVERT(nvarchar(128), SERVERPROPERTY(N'ServerName')),
        @CollectionRunId bigint,
        @WaitStatsRows int = NULL,
        @FileIoRows int = NULL,
        @ServerResourceRows int = NULL,
        @MissingIndexRows int = NULL,
        @DeleteBefore datetime2(0);

    SELECT @SqlServerStartTime = CONVERT(datetime2(0), sqlserver_start_time)
    FROM sys.dm_os_sys_info;

    INSERT dbo.PerformanceCollectorRun
    (
        ServerName, StartTime, SqlServerStartTime, RetentionDays, DatabaseScope, Succeeded, CollectorVersion
    )
    VALUES
    (
        @ServerName, @StartTime, @SqlServerStartTime, @RetentionDays, @Databases, NULL, @Version
    );

    SET @CollectionRunId = SCOPE_IDENTITY();

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM @SelectedScope WHERE ScopeName = N'WAITSTATS')
        BEGIN
            INSERT dbo.PerformanceWaitStats
            (
                CollectionRunId, CaptureTime, SqlServerStartTime, ServerName, WaitType,
                WaitingTasksCount, WaitTimeMs, MaxWaitTimeMs, SignalWaitTimeMs
            )
            SELECT
                @CollectionRunId, @CaptureTime, @SqlServerStartTime, @ServerName, wait_type,
                waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms
            FROM sys.dm_os_wait_stats
            WHERE waiting_tasks_count > 0 OR wait_time_ms > 0;

            SET @WaitStatsRows = @@ROWCOUNT;
        END;

        IF EXISTS (SELECT 1 FROM @SelectedScope WHERE ScopeName = N'FILEIO')
        BEGIN
            INSERT dbo.PerformanceFileIo
            (
                CollectionRunId, CaptureTime, SqlServerStartTime, ServerName, DatabaseId, DatabaseName, FileId,
                LogicalFileName, PhysicalFileName, FileType, NumOfReads, NumOfBytesRead, IoStallReadMs,
                NumOfWrites, NumOfBytesWritten, IoStallWriteMs, IoStallQueuedReadMs,
                IoStallQueuedWriteMs, SizeOnDiskBytes
            )
            SELECT
                @CollectionRunId, @CaptureTime, @SqlServerStartTime, @ServerName, v.database_id, d.DatabaseName,
                v.file_id, m.name, m.physical_name, m.type_desc, v.num_of_reads, v.num_of_bytes_read,
                v.io_stall_read_ms, v.num_of_writes, v.num_of_bytes_written, v.io_stall_write_ms,
                v.io_stall_queued_read_ms, v.io_stall_queued_write_ms, v.size_on_disk_bytes
            FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS v
            JOIN sys.master_files AS m
              ON m.database_id = v.database_id
             AND m.file_id = v.file_id
            JOIN @DB AS d
              ON d.DatabaseId = v.database_id;

            SET @FileIoRows = @@ROWCOUNT;
        END;

        IF EXISTS (SELECT 1 FROM @SelectedScope WHERE ScopeName = N'SERVERRESOURCE')
        BEGIN
            DECLARE
                @TotalServerMemoryKb bigint =
                    (
                        SELECT MAX(cntr_value)
                        FROM sys.dm_os_performance_counters
                        WHERE object_name LIKE N'%Memory Manager%'
                          AND counter_name = N'Total Server Memory (KB)'
                          AND instance_name = N''
                    ),
                @TargetServerMemoryKb bigint =
                    (
                        SELECT MAX(cntr_value)
                        FROM sys.dm_os_performance_counters
                        WHERE object_name LIKE N'%Memory Manager%'
                          AND counter_name = N'Target Server Memory (KB)'
                          AND instance_name = N''
                    ),
                @MemoryGrantsPending bigint =
                    (
                        SELECT MAX(cntr_value)
                        FROM sys.dm_os_performance_counters
                        WHERE object_name LIKE N'%Memory Manager%'
                          AND counter_name = N'Memory Grants Pending'
                          AND instance_name = N''
                    );

            INSERT dbo.PerformanceServerResource
            (
                CollectionRunId, CaptureTime, SqlServerStartTime, ServerName, TotalPhysicalMemoryKb,
                AvailablePhysicalMemoryKb, SystemMemoryState, SqlPhysicalMemoryInUseKb,
                LockedPagesAllocatedKb, LargePageAllocationsKb, ProcessPhysicalMemoryLow,
                ProcessVirtualMemoryLow, TotalServerMemoryKb, TargetServerMemoryKb, MemoryGrantsPending,
                OnlineSchedulers, CurrentTasks, RunnableTasks, CurrentWorkers, ActiveWorkers, WorkQueueCount,
                PendingDiskIoCount, UserConnections, ActiveRequests, BlockedRequests
            )
            SELECT
                @CollectionRunId, @CaptureTime, @SqlServerStartTime, @ServerName,
                sm.total_physical_memory_kb, sm.available_physical_memory_kb, sm.system_memory_state_desc,
                pm.physical_memory_in_use_kb, pm.locked_page_allocations_kb, pm.large_page_allocations_kb,
                pm.process_physical_memory_low, pm.process_virtual_memory_low,
                @TotalServerMemoryKb, @TargetServerMemoryKb, @MemoryGrantsPending,
                schedulers.OnlineSchedulers, schedulers.CurrentTasks, schedulers.RunnableTasks,
                schedulers.CurrentWorkers, schedulers.ActiveWorkers, schedulers.WorkQueueCount,
                schedulers.PendingDiskIoCount, sessions.UserConnections,
                requests.ActiveRequests, requests.BlockedRequests
            FROM sys.dm_os_sys_memory AS sm
            CROSS JOIN sys.dm_os_process_memory AS pm
            CROSS JOIN
            (
                SELECT
                    COUNT(*) AS OnlineSchedulers,
                    SUM(CONVERT(bigint, current_tasks_count)) AS CurrentTasks,
                    SUM(CONVERT(bigint, runnable_tasks_count)) AS RunnableTasks,
                    SUM(CONVERT(bigint, current_workers_count)) AS CurrentWorkers,
                    SUM(CONVERT(bigint, active_workers_count)) AS ActiveWorkers,
                    SUM(CONVERT(bigint, work_queue_count)) AS WorkQueueCount,
                    SUM(CONVERT(bigint, pending_disk_io_count)) AS PendingDiskIoCount
                FROM sys.dm_os_schedulers
                WHERE status = N'VISIBLE ONLINE'
            ) AS schedulers
            CROSS JOIN
            (
                SELECT COUNT(*) AS UserConnections
                FROM sys.dm_exec_sessions
                WHERE is_user_process = 1
            ) AS sessions
            CROSS JOIN
            (
                SELECT
                    COUNT(*) AS ActiveRequests,
                    COALESCE(SUM(CASE WHEN blocking_session_id > 0 THEN 1 ELSE 0 END), 0) AS BlockedRequests
                FROM sys.dm_exec_requests
                WHERE session_id <> @@SPID
            ) AS requests;

            SET @ServerResourceRows = @@ROWCOUNT;
        END;

        IF EXISTS (SELECT 1 FROM @SelectedScope WHERE ScopeName = N'MISSINGINDEX')
        BEGIN
            INSERT dbo.PerformanceMissingIndex
            (
                CollectionRunId, CaptureTime, SqlServerStartTime, ServerName, DatabaseId, DatabaseName,
                ObjectId, SchemaName, ObjectName, IndexHandle, IndexGroupHandle, RecommendationHash,
                EqualityColumns, InequalityColumns, IncludedColumns, UniqueCompiles, UserSeeks, UserScans,
                LastUserSeek, LastUserScan, AvgTotalUserCost, AvgUserImpact, SystemSeeks, SystemScans,
                LastSystemSeek, LastSystemScan, AvgTotalSystemCost, AvgSystemImpact
            )
            SELECT
                @CollectionRunId, @CaptureTime, @SqlServerStartTime, @ServerName, mid.database_id, d.DatabaseName,
                mid.object_id, OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id),
                OBJECT_NAME(mid.object_id, mid.database_id), mid.index_handle, mig.index_group_handle,
                HASHBYTES
                (
                    'SHA2_256',
                    CONCAT
                    (
                        CONVERT(nvarchar(max), N''),
                        CONVERT(nvarchar(11), mid.database_id), N'|',
                        CONVERT(nvarchar(11), mid.object_id), N'|',
                        COALESCE(mid.equality_columns, N''), N'|',
                        COALESCE(mid.inequality_columns, N''), N'|',
                        COALESCE(mid.included_columns, N'')
                    )
                ),
                mid.equality_columns, mid.inequality_columns, mid.included_columns,
                migs.unique_compiles, migs.user_seeks, migs.user_scans,
                migs.last_user_seek, migs.last_user_scan, migs.avg_total_user_cost, migs.avg_user_impact,
                migs.system_seeks, migs.system_scans, migs.last_system_seek, migs.last_system_scan,
                migs.avg_total_system_cost, migs.avg_system_impact
            FROM sys.dm_db_missing_index_details AS mid
            JOIN sys.dm_db_missing_index_groups AS mig
              ON mig.index_handle = mid.index_handle
            JOIN sys.dm_db_missing_index_group_stats AS migs
              ON migs.group_handle = mig.index_group_handle
                        JOIN @DB AS d
                            ON d.DatabaseId = mid.database_id;

            SET @MissingIndexRows = @@ROWCOUNT;
        END;

        SET @DeleteBefore = DATEADD(day, -@RetentionDays, @CaptureTime);

        WHILE 1 = 1
        BEGIN
            DELETE TOP (10000) FROM dbo.PerformanceWaitStats WHERE CaptureTime < @DeleteBefore;
            IF @@ROWCOUNT < 10000 BREAK;
        END;

        WHILE 1 = 1
        BEGIN
            DELETE TOP (10000) FROM dbo.PerformanceFileIo WHERE CaptureTime < @DeleteBefore;
            IF @@ROWCOUNT < 10000 BREAK;
        END;

        WHILE 1 = 1
        BEGIN
            DELETE TOP (10000) FROM dbo.PerformanceServerResource WHERE CaptureTime < @DeleteBefore;
            IF @@ROWCOUNT < 10000 BREAK;
        END;

        WHILE 1 = 1
        BEGIN
            DELETE TOP (10000) FROM dbo.PerformanceMissingIndex WHERE CaptureTime < @DeleteBefore;
            IF @@ROWCOUNT < 10000 BREAK;
        END;

        DELETE runRow
        FROM dbo.PerformanceCollectorRun AS runRow
        WHERE runRow.StartTime < @DeleteBefore
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.PerformanceWaitStats AS waitRow
              WHERE waitRow.CollectionRunId = runRow.CollectionRunId
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.PerformanceFileIo AS fileRow
              WHERE fileRow.CollectionRunId = runRow.CollectionRunId
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.PerformanceServerResource AS resourceRow
              WHERE resourceRow.CollectionRunId = runRow.CollectionRunId
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.PerformanceMissingIndex AS indexRow
              WHERE indexRow.CollectionRunId = runRow.CollectionRunId
          );

        UPDATE dbo.PerformanceCollectorRun
        SET EndTime = SYSDATETIME(),
            WaitStatsRows = @WaitStatsRows,
            FileIoRows = @FileIoRows,
            ServerResourceRows = @ServerResourceRows,
            MissingIndexRows = @MissingIndexRows,
            Succeeded = 1
        WHERE CollectionRunId = @CollectionRunId;

        DECLARE @Message nvarchar(2048) = CONCAT
        (
            N'Performance collection completed. RunId=', @CollectionRunId,
            N'; WaitStats=', @WaitStatsRows,
            N'; FileIo=', @FileIoRows,
            N'; ServerResource=', @ServerResourceRows,
            N'; MissingIndexes=', @MissingIndexRows, N'.'
        );
        RAISERROR('%s', 10, 1, @Message) WITH NOWAIT;
    END TRY
    BEGIN CATCH
        UPDATE dbo.PerformanceCollectorRun
        SET EndTime = SYSDATETIME(),
            WaitStatsRows = @WaitStatsRows,
            FileIoRows = @FileIoRows,
            ServerResourceRows = @ServerResourceRows,
            MissingIndexRows = @MissingIndexRows,
            Succeeded = 0,
            ErrorNumber = ERROR_NUMBER(),
            ErrorMessage = ERROR_MESSAGE()
        WHERE CollectionRunId = @CollectionRunId;

        THROW;
    END CATCH;
END;
GO

USE msdb;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @JobName sysname = N'PerformanceCollector - Hourly';
DECLARE @ScheduleName sysname = N'PerformanceCollector - Hourly at minute 17';
DECLARE @JobId uniqueidentifier;
DECLARE @StepId int;
DECLARE @ScheduleId int;
DECLARE @CollectorCommand nvarchar(max) =
    N'USE master; EXEC dbo.PerformanceCollector @RetentionDays=90, @Scope=N''MissingIndex,WaitStats,ServerResource,FileIo'', @Databases=N''USER_DATABASES'';';

SELECT @JobId = job_id
FROM dbo.sysjobs
WHERE name = @JobName;

IF @JobId IS NULL
    EXEC dbo.sp_add_job
        @job_name = @JobName,
        @enabled = 1,
        @description = N'Collects hourly SQL Server performance history.',
        @job_id = @JobId OUTPUT;
ELSE
    EXEC dbo.sp_update_job
        @job_name = @JobName,
        @enabled = 1,
        @description = N'Collects hourly SQL Server performance history.';

SELECT @StepId = step_id
FROM dbo.sysjobsteps
WHERE job_id = @JobId
    AND step_name = N'Collect performance data';

IF @StepId IS NOT NULL
    EXEC dbo.sp_update_jobstep
        @job_id = @JobId,
        @step_id = @StepId,
        @subsystem = N'TSQL',
        @database_name = N'master',
        @command = @CollectorCommand,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 2,
        @retry_interval = 5;
ELSE
    EXEC dbo.sp_add_jobstep
        @job_id = @JobId,
        @step_name = N'Collect performance data',
        @subsystem = N'TSQL',
        @database_name = N'master',
        @command = @CollectorCommand,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 2,
        @retry_interval = 5;

SELECT @ScheduleId = schedule_id
FROM dbo.sysschedules
WHERE name = @ScheduleName;

IF @ScheduleId IS NULL
    EXEC dbo.sp_add_schedule
        @schedule_name = @ScheduleName,
        @enabled = 1,
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 1,
        @active_start_time = 001700,
        @schedule_id = @ScheduleId OUTPUT;
ELSE
    EXEC dbo.sp_update_schedule
        @schedule_id = @ScheduleId,
        @enabled = 1,
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 1,
        @active_start_time = 001700;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.sysjobschedules
    WHERE job_id = @JobId AND schedule_id = @ScheduleId
)
    EXEC dbo.sp_attach_schedule @job_id = @JobId, @schedule_id = @ScheduleId;

IF NOT EXISTS (SELECT 1 FROM dbo.sysjobservers WHERE job_id = @JobId)
    EXEC dbo.sp_add_jobserver @job_id = @JobId;
GO