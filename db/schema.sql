CREATE TABLE logs (
  id bigserial PRIMARY KEY,
  log_file varchar(255),
  bucket varchar(255),
  processed boolean DEFAULT false NOT NULL
);

CREATE TABLE requests (
  id bigserial PRIMARY KEY,
  log_file varchar(255),
  bucket varchar(255),
  time timestamptz,
  remote_ip varchar(255),
  operation varchar(255),
  key text,
  request_uri text,
  http_status integer,
  error_code varchar(255),
  bytes_sent integer,
  object_size integer,
  total_time integer,
  turn_around_time integer,
  referrer text,
  user_agent text
);

CREATE INDEX idx_requests_on_key  ON requests USING btree (key);
CREATE INDEX idx_requests_on_time ON requests USING btree (time);
