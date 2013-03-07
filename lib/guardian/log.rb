require 'guardian/database'

module Guardian
  Log = Struct.new(:id, :bucket, :log_file) do
    CREATE_STATEMENT = <<-SQL
      INSERT INTO logs (log_file, bucket) VALUES ($1, $2)
      RETURNING id, log_file, bucket
    SQL

    FIND_STATEMENT = <<-SQL
      SELECT id, bucket, log_file
      FROM logs
      WHERE id = $1
    SQL

    LAST_LOG_FILE_STATEMENT = <<-SQL
      SELECT log_file
      FROM logs
      WHERE bucket = $1
      ORDER BY id DESC
      LIMIT 1
    SQL

    def self.create(bucket, log_file)
      row = Database.execute(CREATE_STATEMENT, log_file, bucket)
      Log.new(row['id'], row['bucket'], row['log_file'])
    end

    def self.find(id)
      row = Database.execute(FIND_STATEMENT, id)
      Log.new(row['id'], row['bucket'], row['log_file'])
    end

    def self.last_log_file_for_bucket(bucket)
      row = Database.execute(LAST_LOG_FILE_STATEMENT, bucket)
      row && row['log_file']
    end
  end
end
