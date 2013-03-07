require 'queue_classic'
ENV['DATABASE_URL'] ||= 'postgres://localhost/guardian_test'

RSpec.configure do |c|
  c.before(:suite) do
    database_name = Guardian::Database.db_url.path.gsub('/', '')
    `dropdb #{database_name}`
    `createdb #{database_name}`
    Guardian::Database.execute "SET client_min_messages TO 'warning'"
    Guardian::Database.execute File.read('db/schema.sql')
    QC::Setup.create
    Guardian::Database.disconnect
  end

  c.around do |example|
    Guardian::Database.execute("BEGIN")
    example.run
    Guardian::Database.execute("ROLLBACK")
    Guardian::Database.disconnect
  end
end
