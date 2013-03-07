# QC needs a database in the environment.
ENV['DATABASE_URL'] ||= 'postgres://localhost/guardian_test'

require 'queue_classic'

module Guardian
  Database = QC::Conn
end
