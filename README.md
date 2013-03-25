# Guardian

Guardian imports Amazon S3 access logs into a local Postgres database. Useful
for reporting on usage and keeping an eye on transfer costs.

## Setup

### Enable bucket logging

[Sign into S3][s3] and enable logging for the bucket whose access you want to
track. **Target Bucket** is the bucket where Amazon will copy the access
logs for the selected bucket. It can be a completely separate bucket from the
one whose access is being logged.

![Enable S3 bucket logging][enable-logging]

### Deploy

Clone Guardian and deploy it. Heroku makes this simple. If deploying to
Heroku, know that Guardian requires at least 2 processes: one to run clockwork
and another to process jobs.

```bash
$ git clone https://github.com/cloudapp/guardian
$ cd guardian
$ heroku create
$ git push heroku master
```

### Upgrade database (optional)

The development database Heroku provides by default allows up to 10,000 rows.
Upgrade to Basic for 10mm rows or Crane for 1TB of storage.

```bash
$ heroku addons:add heroku-postgresql:dev
Adding heroku-postgresql:dev to sushi... done, v69 (free)
  Attached as HEROKU_POSTGRESQL_RED

$ heroku pg:promote HEROKU_POSTGRESQL_RED_URL
Promoting HEROKU_POSTGRESQL_RED_URL to DATABASE_URL... done
```

### Add AWS credentials

Guardian depends on 3 environment variables in order to read access logs:
`AWS_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY`. The
bucket name is the bucket configured as the **Target Bucket** in the first
step. The **Access Key ID** and **Secret Access Key** can be found on the [AWS
Access Credentials][access-credentials] page.

```bash
$ heroku config:add AWS_BUCKET_NAME=my-bucket \
                    AWS_ACCESS_KEY_ID=ABC123 \
                    AWS_SECRET_ACCESS_KEY=DEF456
```

### Start Guardian

If you're using Heroku, kickstart Guardian using `script/rebuild` passing it
the Heroku app's name. This will scale the `clock` and `worker` processes to
0, rebuild the database, and scale `clock` to 1 and `worker` to 15 in order to
churn through the backlog.

```bash
$ script/rebuild my-app
```

## Reporting

[Heroku Dataclips][dataclips] make it easy to generate a bucket activity
report. Here's a query that shows the top 50 most trafficked files from the
past day.

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

**Note:** Don't assume the access logs Amazon provides will be accurate up to
the minute. The way Amazon delivers access logs, the previous 2 hours may not
be fully represented.


[s3]:                 https://console.aws.amazon.com/s3
[enable-logging]:     http://cl.ly/image/0Z2f2u0N3i1e/S3%20Bucket%20Logging.png
[access-credentials]: https://portal.aws.amazon.com/gp/aws/securityCredentials#access_credentials
[dataclips]:          https://postgres.heroku.com/dataclips
