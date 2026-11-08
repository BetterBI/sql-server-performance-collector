# Deployment

Version 1 stores hourly observations of server-wide missing-index recommendations in a dedicated DBA database. It never creates, alters, disables, or drops application indexes. Developed by Thomas Grubbe Møller of BetterBI ApS.

## Requirements

- SQL Server 2016 or later.
- A dedicated DBA/administration database. Do not install the table in a vendor or application database.
- SQL Server Agent for the built-in schedule. SQL Server Express does not include SQL Server Agent.
- The Agent job execution identity needs access to the DBA database, `EXECUTE` on `dbo.CollectMissingIndexHistory`, and `SELECT`, `INSERT`, and `DELETE` rights on `dbo.MissingIndexLog`.
- On SQL Server 2019 and earlier, grant `VIEW SERVER STATE`. On SQL Server 2022 and later, grant `VIEW SERVER PERFORMANCE STATE`.
- The installer identity needs permission to manage SQL Server Agent jobs in `msdb`.

Metadata visibility can affect the schema and object names returned by `OBJECT_SCHEMA_NAME` and `OBJECT_NAME`.

## Install

1. Create or select a dedicated DBA database.
2. Run the [table and index example](sql-examples.md#table-and-index-example) in that database. It is idempotent.
3. Run [`sql-server-performance-collector.sql`](../sql-server-performance-collector.sql) in the DBA database to install `dbo.CollectMissingIndexHistory` and capture an initial snapshot. Rerunning the script updates the procedure and captures another snapshot. A successful run with zero recommendations is valid.
4. In SQL Server Management Studio, enable SQLCMD Mode and run the [Agent job example](sql-examples.md#agent-job-example). Set `DBA_DATABASE` to the dedicated database name. The job step calls the installed procedure and does not depend on a local checkout.
5. The schedule runs hourly at minute 17. To capture immediately, start `DBA - Collect Missing Index History` manually in SQL Server Agent.
6. Run the [smoke-test example](sql-examples.md#smoke-test-example) in the DBA database. An empty result set is valid when there are no recommendations.

The collector records `CaptureTimeUtc` with `SYSUTCDATETIME()`. It derives SQL Server startup UTC from the engine startup and current millisecond ticks. The recommendation hash is SHA-256 over database/object identifiers and trimmed recommendation column lists; raw DMV column lists are stored unchanged.

## Retention and interpretation

Rows older than 90 days are deleted in batches of 10,000 during collection. Missing-index DMV counters are cumulative since their last reset, not interval deltas. They can reset after an engine restart and other engine or database events. Use `SqlServerStartTimeUtc` to help identify engine restarts. Last-use timestamps and costs are stored as returned by SQL Server.

Missing-index recommendations are advisory and limited. Similar recommendations can overlap, and they do not capture every workload or operational cost. Review recommendations independently; this collector only stores observations.

## Uninstall

There is no uninstall script. Disable or delete the Agent job to stop collection. To remove the data, separately review and manually drop `dbo.MissingIndexLog` and its indexes from the DBA database. Dropping the table permanently deletes the collected history.

## Validation

Run the installation, collector, Agent job, and smoke-test examples against a non-production SQL Server instance before operational use. This repository does not include automated CI or deployment workflows.
