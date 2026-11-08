/*
Purpose: Install and execute the server-wide missing-index collector.
Developed by: Thomas Grubbe Møller of BetterBI ApS.
Schedule: SQL Server Agent, hourly at minute 17.
Run in: The DBA database containing dbo.MissingIndexLog.
Required permission: VIEW SERVER STATE (SQL Server 2019 and earlier), or
VIEW SERVER PERFORMANCE STATE (SQL Server 2022 and later).
*/
IF OBJECT_ID(N'dbo.CollectMissingIndexHistory', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.CollectMissingIndexHistory AS RETURN 0;');
GO

ALTER PROCEDURE dbo.CollectMissingIndexHistory
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID(N'dbo.MissingIndexLog', N'U') IS NULL
        THROW 50001, 'dbo.MissingIndexLog does not exist. See the installation example in docs/deployment.md.', 1;

    DECLARE @CaptureBatchId uniqueidentifier = NEWID();
    DECLARE @CaptureTimeUtc datetime2(0) = SYSUTCDATETIME();
    DECLARE @SqlServerStartTimeUtc datetime2(0);
    DECLARE @ElapsedMilliseconds bigint;
    DECLARE @ServerName nvarchar(128) = CONVERT(nvarchar(128), SERVERPROPERTY(N'ServerName'));

    SELECT
        @ElapsedMilliseconds = DATEDIFF_BIG(MILLISECOND, sqlserver_start_time, SYSDATETIME())
    FROM sys.dm_os_sys_info;

    SET @SqlServerStartTimeUtc = DATEADD
    (
        MILLISECOND,
        -CONVERT(int, @ElapsedMilliseconds % 86400000),
        DATEADD
        (
            DAY,
            -CONVERT(int, @ElapsedMilliseconds / 86400000),
            @CaptureTimeUtc
        )
    );

    INSERT dbo.MissingIndexLog
    (
        CaptureBatchId, CaptureTimeUtc, SqlServerStartTimeUtc, ServerName,
        DatabaseId, DatabaseName, ObjectId, SchemaName, ObjectName,
        IndexHandle, IndexGroupHandle, RecommendationHash,
        EqualityColumns, InequalityColumns, IncludedColumns,
        UniqueCompiles, UserSeeks, UserScans, LastUserSeek, LastUserScan,
        AvgTotalUserCost, AvgUserImpact, SystemSeeks, SystemScans,
        LastSystemSeek, LastSystemScan, AvgTotalSystemCost, AvgSystemImpact
    ),
    SELECT
        @CaptureBatchId,
        @CaptureTimeUtc,
        @SqlServerStartTimeUtc,
        @ServerName,
        mid.database_id,
        d.name,
        mid.object_id,
        OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id),
        OBJECT_NAME(mid.object_id, mid.database_id),
        mid.index_handle,
        mig.index_group_handle,
        HASHBYTES
        (
            'SHA2_256',
            CONCAT
            (
                CONVERT(nvarchar(max), CONVERT(nvarchar(11), mid.database_id)), N'|',
                CONVERT(nvarchar(11), mid.object_id), N'|',
                LTRIM(RTRIM(COALESCE(mid.equality_columns, N''))), N'|',
                LTRIM(RTRIM(COALESCE(mid.inequality_columns, N''))), N'|',
                LTRIM(RTRIM(COALESCE(mid.included_columns, N'')))
            )
        ),
        mid.equality_columns,
        mid.inequality_columns,
        mid.included_columns,
        migs.unique_compiles,
        migs.user_seeks,
        migs.user_scans,
        migs.last_user_seek,
        migs.last_user_scan,
        migs.avg_total_user_cost,
        migs.avg_user_impact,
        migs.system_seeks,
        migs.system_scans,
        migs.last_system_seek,
        migs.last_system_scan,
        migs.avg_total_system_cost,
        migs.avg_system_impact
    FROM sys.dm_db_missing_index_details AS mid
    JOIN sys.dm_db_missing_index_groups AS mig
      ON mig.index_handle = mid.index_handle
    JOIN sys.dm_db_missing_index_group_stats AS migs
      ON migs.group_handle = mig.index_group_handle
    JOIN sys.databases AS d
      ON d.database_id = mid.database_id
    WHERE d.database_id > 4
      AND d.state_desc = N'ONLINE'
      AND d.source_database_id IS NULL
      AND HAS_DBACCESS(d.name) = 1;

    DECLARE @RowsCaptured int = @@ROWCOUNT;
    DECLARE @DeleteBeforeUtc datetime2(0) = DATEADD(day, -90, @CaptureTimeUtc);
    DECLARE @RowsDeleted int = 1;
    DECLARE @TotalRowsDeleted bigint = 0;

    WHILE @RowsDeleted > 0
    BEGIN
        DELETE TOP (10000)
        FROM dbo.MissingIndexLog
        WHERE CaptureTimeUtc < @DeleteBeforeUtc;

        SET @RowsDeleted = @@ROWCOUNT;
        SET @TotalRowsDeleted += @RowsDeleted;
    END;

    DECLARE @Message nvarchar(2048) = CONCAT
    (
        N'Missing-index collection completed. Batch=',
        CONVERT(nvarchar(36), @CaptureBatchId),
        N'; captured=', @RowsCaptured,
        N'; retention_deleted=', @TotalRowsDeleted, N'.'
    );
    RAISERROR(@Message, 10, 1) WITH NOWAIT;
END;
GO

EXEC dbo.CollectMissingIndexHistory;
