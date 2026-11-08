# SQL Examples

These examples show the supporting installation, SQL Server Agent, and validation steps. The runnable collector is [`sql-server-performance-collector.sql`](../sql-server-performance-collector.sql). Developed by Thomas Grubbe Møller of BetterBI ApS.

## Table and index example

Run in a dedicated DBA/administration database. It creates the only permanent application table and is safe to rerun.

```sql
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.MissingIndexLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MissingIndexLog
    (
        MissingIndexLogId      bigint IDENTITY(1,1) NOT NULL,
        CaptureBatchId         uniqueidentifier NOT NULL,
        CaptureTimeUtc         datetime2(0) NOT NULL,
        SqlServerStartTimeUtc  datetime2(0) NOT NULL,
        ServerName             nvarchar(128) NOT NULL,
        DatabaseId             int NOT NULL,
        DatabaseName           sysname NOT NULL,
        ObjectId               int NOT NULL,
        SchemaName             sysname NULL,
        ObjectName             sysname NULL,
        IndexHandle            int NOT NULL,
        IndexGroupHandle       int NOT NULL,
        RecommendationHash     binary(32) NOT NULL,
        EqualityColumns        nvarchar(4000) NULL,
        InequalityColumns      nvarchar(4000) NULL,
        IncludedColumns        nvarchar(4000) NULL,
        UniqueCompiles         bigint NOT NULL,
        UserSeeks              bigint NOT NULL,
        UserScans              bigint NOT NULL,
        LastUserSeek           datetime NULL,
        LastUserScan           datetime NULL,
        AvgTotalUserCost       float NOT NULL,
        AvgUserImpact          float NOT NULL,
        SystemSeeks            bigint NOT NULL,
        SystemScans            bigint NOT NULL,
        LastSystemSeek         datetime NULL,
        LastSystemScan         datetime NULL,
        AvgTotalSystemCost     float NOT NULL,
        AvgSystemImpact        float NOT NULL,
        ImprovementMeasure AS
        (
            (CONVERT(float, UserSeeks) + CONVERT(float, UserScans))
            * AvgTotalUserCost
            * AvgUserImpact / 100.0
        ) PERSISTED,
        CONSTRAINT PK_MissingIndexLog
            PRIMARY KEY CLUSTERED (MissingIndexLogId)
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.MissingIndexLog')
      AND name = N'IX_MissingIndexLog_CaptureTimeUtc'
)
    CREATE INDEX IX_MissingIndexLog_CaptureTimeUtc
        ON dbo.MissingIndexLog (CaptureTimeUtc);

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.MissingIndexLog')
      AND name = N'IX_MissingIndexLog_Recommendation'
)
    CREATE INDEX IX_MissingIndexLog_Recommendation
        ON dbo.MissingIndexLog
        (
            DatabaseId,
            ObjectId,
            RecommendationHash,
            CaptureTimeUtc
        )
        INCLUDE
        (
            DatabaseName,
            SchemaName,
            ObjectName,
            UserSeeks,
            UserScans,
            AvgUserImpact
        );
```

## Agent job example

Run in SQLCMD Mode from SQL Server Management Studio. Set `DBA_DATABASE` to the database containing `dbo.MissingIndexLog` and `dbo.CollectMissingIndexHistory`. This example creates or updates the hourly job; its step calls the collector procedure installed by [`sql-server-performance-collector.sql`](../sql-server-performance-collector.sql).

```sql
:setvar DBA_DATABASE "DBA"
USE msdb;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @DatabaseName sysname = N'$(DBA_DATABASE)';
DECLARE @JobName sysname = N'DBA - Collect Missing Index History';
DECLARE @ScheduleName sysname = N'DBA - Hourly at minute 17';
DECLARE @JobId uniqueidentifier;
DECLARE @ScheduleId int;
DECLARE @CollectorCommand nvarchar(max) = N'EXEC dbo.CollectMissingIndexHistory;';

IF DB_ID(@DatabaseName) IS NULL
    THROW 50002, 'The DBA_DATABASE SQLCMD variable must name an existing database.', 1;
IF OBJECT_ID(QUOTENAME(@DatabaseName) + N'.dbo.MissingIndexLog', N'U') IS NULL
    THROW 50003, 'dbo.MissingIndexLog was not found in DBA_DATABASE.', 1;

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC dbo.sp_update_job
        @job_name = @JobName,
        @enabled = 1,
        @description = N'Collects server-wide missing-index DMV history into dbo.MissingIndexLog.';
    SELECT @JobId = job_id FROM dbo.sysjobs WHERE name = @JobName;
END;
ELSE
BEGIN
    EXEC dbo.sp_add_job
        @job_name = @JobName,
        @enabled = 1,
        @description = N'Collects server-wide missing-index DMV history into dbo.MissingIndexLog.',
        @job_id = @JobId OUTPUT;
END;

IF EXISTS
(
    SELECT 1 FROM dbo.sysjobsteps
    WHERE job_id = @JobId
      AND step_name = N'Capture missing-index snapshot'
)
    EXEC dbo.sp_update_jobstep
        @job_id = @JobId,
        @step_name = N'Capture missing-index snapshot',
        @subsystem = N'TSQL',
        @database_name = @DatabaseName,
        @command = @CollectorCommand,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 2,
        @retry_interval = 5;
ELSE
    EXEC dbo.sp_add_jobstep
        @job_id = @JobId,
        @step_name = N'Capture missing-index snapshot',
        @subsystem = N'TSQL',
        @database_name = @DatabaseName,
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
```

## Smoke-test example

Run in the DBA database after a collector execution. No result rows is a valid outcome.

```sql
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.MissingIndexLog', N'U') IS NULL
    THROW 51000, 'FAIL: dbo.MissingIndexLog was not created.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.MissingIndexLog')
      AND name = N'IX_MissingIndexLog_CaptureTimeUtc'
)
    THROW 51001, 'FAIL: capture-time index was not created.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.MissingIndexLog')
      AND name = N'IX_MissingIndexLog_Recommendation'
)
    THROW 51002, 'FAIL: recommendation index was not created.', 1;

SELECT TOP (100)
    CaptureTimeUtc,
    SqlServerStartTimeUtc,
    ServerName,
    DatabaseName,
    SchemaName,
    ObjectName,
    EqualityColumns,
    InequalityColumns,
    IncludedColumns,
    UserSeeks,
    UserScans,
    AvgUserImpact,
    ImprovementMeasure
FROM dbo.MissingIndexLog
ORDER BY MissingIndexLogId DESC;
```