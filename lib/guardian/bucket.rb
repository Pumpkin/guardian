require 'guardian/aws'
require 'guardian/log'
require 'guardian/request'
require 'guardian/worker'
require 'queue_classic'
require 'tempfile'

module Guardian
  Bucket = Struct.new(:name, :access, :secret) do
    def self.by_name name, buckets = BUCKETS
      buckets.find {|bucket| bucket.name == name }
    end

    def self.enqueue_processing_new_logs buckets = BUCKETS, queue = Guardian::Queue
      buckets.each do |bucket|
        queue.enqueue 'Guardian::Bucket.process_new_logs', bucket.name
      end
    end

    # TODO: Combine .process_new_logs and #process_new_logs_since
    def self.process_new_logs name, buckets = Guardian::Bucket, log = Guardian::Log
      last_log_file = log.last_log_file_for_bucket(name) || default_log_file
      buckets.by_name(name).process_new_logs_since(last_log_file, log)
    end

    def self.default_log_file
      yesterday = Time.now - 60*60*24
      yesterday.strftime 'logs/access_log-%Y-%m-%d-%H'
    end

    def process_new_logs_since last_log_file, log, aws = Guardian::AWS, queue = Guardian::Queue, logger = $stderr
      logger.puts "Fetching logs bucket: #{self.name} since: #{last_log_file}"
      aws.files_for_bucket_since(self, last_log_file).each do |log_file|
        log.create(name, log_file)
        queue.enqueue('Guardian::Bucket.process_log_file', name, log_file)
      end
    end

    def self.process_log_file name, log_file, buckets = Guardian::Bucket
      buckets.by_name(name).process_log_file(log_file)
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

  # Format: AWS_ACCOUNTS=bucket,access,secret,bucket,access,secret...
  if ENV['AWS_ACCOUNTS']
    BUCKETS = ENV['AWS_ACCOUNTS'].
                split(',').
                each_slice(3).
                map {|(bucket, access, secret)|
      Bucket.new(bucket, access, secret)
    }
  end
end
