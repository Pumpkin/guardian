$: << 'lib'

desc 'Work the job queue'
task :work do
  require 'guardian/worker'

  trap('INT')  { exit }
  trap('TERM') { @worker.stop }
  @worker = Guardian::Worker.new
  @worker.start
end

desc 'Destroy and rebuild production database'
task :rebuild do
  require 'heroku/auth'
  require 'heroku/command/base'
  require 'heroku/client/heroku_postgresql'
  require 'heroku/helpers/heroku_postgresql'

  class ResetDatabase < Heroku::Command::Base
    include Heroku::Helpers::HerokuPostgresql
    def reset
      Heroku::Client::HerokuPostgresql.new(database).reset
    end

    def database
      hpg_resolve('DATABASE_URL')
    end

    def database_url
      database.url
    end
  end

  # Setup the production database before queue_classic is loaded.
  ENV['DATABASE_URL'] ||= ResetDatabase.new.database_url
  require 'guardian/bucket'

  print 'Scaling down clock... '
  new_qty = Heroku::Auth.api.post_ps_scale('cl-guardian-test', 'clock', 0).body
  puts "scaled to #{new_qty}"

  print 'Scaling down workers... '
  new_qty = Heroku::Auth.api.post_ps_scale('cl-guardian-test', 'worker', 0).body
  puts "scaled to #{new_qty}"

  print 'Resetting database... '
  ResetDatabase.new.reset
  puts 'done'

  print 'Importing schema... '
  Guardian::Database.execute "SET client_min_messages TO 'warning'"
  Guardian::Database.execute File.read('db/schema.sql')
  QC::Setup.create
  puts 'done'

  print 'Scaling up clock... '
  new_qty = Heroku::Auth.api.post_ps_scale('cl-guardian-test', 'clock', 1).body
  puts "scaled to #{ new_qty }"

  print 'Scaling up workers... '
  new_qty = Heroku::Auth.api.post_ps_scale('cl-guardian-test', 'worker', 15).body
  puts "scaled to #{ new_qty }"
end
