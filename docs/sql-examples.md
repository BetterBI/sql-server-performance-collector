# SQL Examples

These examples cover the SQL Server Agent schedule and validation. Install the tables and procedure by running [`sql-server-performance-collector.sql`](../sql-server-performance-collector.sql) in `master`.

## Agent job example

Run in SQL Server Management Studio as a login allowed to manage SQL Server Agent jobs. The job captures all four scopes hourly at minute 17.

```sql
USE msdb;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @JobName sysname = N'PerformanceCollector - Hourly';
DECLARE @ScheduleName sysname = N'PerformanceCollector - Hourly at minute 17';
DECLARE @JobId uniqueidentifier;
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

IF EXISTS
(
    SELECT 1 FROM dbo.sysjobsteps
    WHERE job_id = @JobId AND step_name = N'Collect performance data'
)
    EXEC dbo.sp_update_jobstep
        @job_id = @JobId,
        @step_name = N'Collect performance data',
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
```

## Smoke-test example

Run in `master` after a collector execution. The latest run reports how many rows were captured for each implemented scope.

```sql
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.PerformanceCollectorRun', N'U') IS NULL
    THROW 51000, 'FAIL: dbo.PerformanceCollectorRun was not created.', 1;
IF OBJECT_ID(N'dbo.PerformanceWaitStats', N'U') IS NULL
    THROW 51001, 'FAIL: dbo.PerformanceWaitStats was not created.', 1;
IF OBJECT_ID(N'dbo.PerformanceFileIo', N'U') IS NULL
    THROW 51002, 'FAIL: dbo.PerformanceFileIo was not created.', 1;
IF OBJECT_ID(N'dbo.PerformanceServerResource', N'U') IS NULL
    THROW 51003, 'FAIL: dbo.PerformanceServerResource was not created.', 1;
IF OBJECT_ID(N'dbo.PerformanceMissingIndex', N'U') IS NULL
    THROW 51004, 'FAIL: dbo.PerformanceMissingIndex was not created.', 1;

SELECT TOP (1)
    CollectionRunId,
    StartTime,
    EndTime,
    WaitStatsRows,
    FileIoRows,
    ServerResourceRows,
    MissingIndexRows,
    Succeeded,
    ErrorNumber,
    ErrorMessage
FROM dbo.PerformanceCollectorRun
ORDER BY CollectionRunId DESC;

SELECT TOP (100)
    CaptureTime,
    SqlServerStartTime,
    ServerName,
    WaitType,
    WaitingTasksCount,
    WaitTimeMs,
    MaxWaitTimeMs,
    SignalWaitTimeMs
FROM dbo.PerformanceWaitStats
ORDER BY CaptureTime DESC, WaitTimeMs DESC;

SELECT TOP (100)
    CaptureTime,
    SqlServerStartTime,
    ServerName,
    DatabaseName,
    LogicalFileName,
    FileType,
    NumOfReads,
    IoStallReadMs,
    NumOfWrites,
    IoStallWriteMs,
    SizeOnDiskBytes
FROM dbo.PerformanceFileIo
ORDER BY CaptureTime DESC, DatabaseName, LogicalFileName;

SELECT TOP (100)
    CaptureTime,
    SqlServerStartTime,
    ServerName,
    TotalPhysicalMemoryKb,
    AvailablePhysicalMemoryKb,
    TotalServerMemoryKb,
    TargetServerMemoryKb,
    MemoryGrantsPending,
    RunnableTasks,
    PendingDiskIoCount,
    BlockedRequests
FROM dbo.PerformanceServerResource
ORDER BY CaptureTime DESC;

SELECT TOP (100)
    CaptureTime,
    SqlServerStartTime,
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
FROM dbo.PerformanceMissingIndex
ORDER BY CaptureTime DESC, ImprovementMeasure DESC;
```