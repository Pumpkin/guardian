require 'guardian/aws'
require 'guardian/log'
require 'guardian/request'
require 'guardian/worker'
require 'queue_classic'
require 'tempfile'

module Guardian
  Bucket = Struct.new(:name, :access, :secret) do
    def self.enqueue_processing_new_logs queue = Guardian::Queue
      queue.enqueue 'Guardian::Bucket.process_new_logs'
    end

    # TODO: Combine .process_new_logs and #process_new_logs_since
    def self.process_new_logs bucket = BUCKET, log = Guardian::Log
      last_log_file = log.last_log_file || default_log_file
      bucket.process_new_logs_since(last_log_file, log)
    end

    # TODO: Move the logic for determining how far back in time to fetch
    # access logs into script/rebuild.
    def self.default_log_file
      yesterday = Time.now - 60*60*24
      yesterday.strftime 'logs/access_log-%Y-%m-%d-%H'
    end

    def process_new_logs_since last_log_file, log, aws = Guardian::AWS,
                               queue = Guardian::Queue, logger = $stderr
      logger.puts "Fetching logs since: #{last_log_file}"
      aws.files_for_bucket_since(self, last_log_file).each do |log_file|
        log.create(log_file)
        queue.enqueue('Guardian::Bucket.process_log_file', log_file)
      end
    end

    def self.process_log_file log_file, bucket = BUCKET
      bucket.process_log_file(log_file)
    end

    def process_log_file log_file, aws = Guardian::AWS,
                         request = Guardian::Request, logger = $stderr
      Tempfile.open('temp') do |file|
        logger.puts "Processing: #{log_file}"
        aws.read_file_from_bucket(self, log_file) do |chunk|
          file.write chunk
        end
        file.rewind
        file.each_line do |line|
          request.record_log_line_from_log_file(log_file, line)
        end
      end
    end
  end

  if ENV['AWS_BUCKET_NAME']
    name   = ENV['AWS_BUCKET_NAME']
    access = ENV['AWS_ACCESS_KEY_ID']
    secret = ENV['AWS_SECRET_ACCESS_KEY']
    BUCKET = Bucket.new(name, access, secret)
  end
end
