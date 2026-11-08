# SQL Server Performance Collector

An open-source T-SQL collector for hourly history of SQL Server missing-index recommendations. Version 1 stores observations only; it never creates, alters, disables, or drops application indexes. Developed by Thomas Grubbe Møller of BetterBI ApS.

## Collector

Run [`sql-server-performance-collector.sql`](sql-server-performance-collector.sql) in the dedicated DBA database to capture a snapshot and apply 90-day retention.

The installation, Agent job, and smoke-test SQL are documented as examples in [SQL examples](docs/sql-examples.md). See the [deployment guide](docs/deployment.md) for requirements and setup.

## Getting Started

Read the [deployment guide](docs/deployment.md) for prerequisites, permissions, installation, validation, limitations, and uninstall guidance. A successful capture with no recommendations is valid.

## Validation

Run the documented smoke-test example against a non-production SQL Server instance before operational use. This repository does not include automated CI or deployment workflows.
