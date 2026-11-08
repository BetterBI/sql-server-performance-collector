# SQL Server Performance Collector

An open-source T-SQL collector for hourly SQL Server performance history. The procedure captures wait statistics, file I/O, server resources, and missing-index recommendations. It never creates, alters, disables, or drops application indexes. Developed by Thomas Grubbe Møller of BetterBI ApS.

## Requirements

- SQL Server 2017 or later.
- Run the installer in `master`, where it creates the `PerformanceCollectorRun` and `Performance*` tables and `dbo.PerformanceCollector` procedure.
- SQL Server Agent for the hourly schedule. SQL Server Express does not include SQL Server Agent.
- The Agent job execution identity needs permission to execute `dbo.PerformanceCollector` in `master` and the required server-state DMV permissions.
- On SQL Server 2019 and earlier, grant `VIEW SERVER STATE`. On SQL Server 2022 and later, grant `VIEW SERVER PERFORMANCE STATE`.
- The installer identity needs permission to manage SQL Server Agent jobs in `msdb`.

Metadata visibility can affect the schema and object names returned by `OBJECT_SCHEMA_NAME` and `OBJECT_NAME`.

## Install

1. Run [`sql-server-performance-collector.sql`](sql-server-performance-collector.sql) in `master`. It creates or updates the collector objects and the hourly Agent job for all four scopes.
2. The job runs hourly at minute 17. To capture immediately, start `PerformanceCollector - Hourly` manually in SQL Server Agent.
3. Run the [smoke-test example](docs/sql-examples.md#smoke-test-example) in `master`. No wait rows or missing-index recommendations is a valid result.

The procedure accepts a comma-separated `@Scope`, defaulting to `MissingIndex`. Supported tokens are `MissingIndex`, `WaitStats`, `ServerResource`, and `FileIo`; pass `N'MissingIndex,WaitStats,ServerResource,FileIo'` to collect all four. `@Databases` defaults to `USER_DATABASES`; alternatively, pass a comma-separated list of online user database names. This selection applies to file I/O and missing-index collection. Wait statistics and server resources are server-wide.

In `PerformanceCollectorRun`, a `NULL` row count means that scope was not requested; zero means it ran but found no rows.

Wait-stat and file-I/O values are stored as cumulative DMV counters, not interval deltas. Counters can reset after an engine restart; use `SqlServerStartTime` to distinguish server lifetimes. Server-resource values are point-in-time snapshots. Missing-index DMV counters are cumulative and advisory. The recommendation hash is SHA-256 over database/object identifiers and trimmed recommendation column lists; raw DMV column lists are stored unchanged.

## Retention and interpretation

Rows older than the configured retention period (90 days by default) are deleted in batches of 10,000 during collection. Missing-index last-use timestamps and costs are stored as returned by SQL Server.

Missing-index recommendations are advisory and limited. Similar recommendations can overlap, and they do not capture every workload or operational cost. Review recommendations independently; this collector only stores observations.

## Uninstall

There is no uninstall script. Disable or delete the Agent job to stop collection. To remove collected history, review and manually drop the `PerformanceWaitStats`, `PerformanceFileIo`, `PerformanceServerResource`, and `PerformanceMissingIndex` tables, then `PerformanceCollectorRun`. Dropping these tables permanently deletes the history. Existing data in the legacy `MissingIndexLog` table is left untouched and is not migrated.

## Validation

Run the installation, collector, Agent job, and smoke-test examples against a non-production SQL Server instance before operational use. This repository does not include automated CI or deployment workflows.
