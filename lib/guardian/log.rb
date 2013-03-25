require 'guardian/database'

module Guardian
  Log = Struct.new(:id, :log_file) do
    CREATE_STATEMENT = <<-SQL
      INSERT INTO logs (log_file) VALUES ($1)
      RETURNING id, log_file
    SQL

    FIND_STATEMENT = <<-SQL
      SELECT id, log_file
      FROM logs
      WHERE id = $1
    SQL

    LAST_LOG_FILE_STATEMENT = <<-SQL
      SELECT log_file
      FROM logs
      ORDER BY id DESC
      LIMIT 1
    SQL

    def self.create(log_file)
      row = Database.execute(CREATE_STATEMENT, log_file)
      Log.new(row['id'], row['log_file'])
    end

    def self.find(id)
      row = Database.execute(FIND_STATEMENT, id)
      Log.new(row['id'], row['log_file'])
    end

    def self.last_log_file
      row = Database.execute(LAST_LOG_FILE_STATEMENT)
      row && row['log_file']
    end
  end
end
