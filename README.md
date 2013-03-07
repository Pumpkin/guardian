# Guardian

Import Amazon S3 access logs into Postgres. Useful for reporting and tracking
transfer costs.

## Setup

_Environment_
_Rake_
_Testing_

## Reporting

Here's a query that shows the top 50 most trafficked files from the past day.
The way Amazon fills logs, the last 2 hours of traffic may not be represented.

``` sql
WITH most_trafficked AS (
  SELECT coalesce(sum(bytes_sent), 0) as transfer, key
  FROM requests
  WHERE
    key is not null AND
    time > current_timestamp - interval '1 day'
  GROUP BY key
  ORDER BY transfer DESC)

SELECT pg_size_pretty(transfer), key
FROM most_trafficked
LIMIT 50;
```
