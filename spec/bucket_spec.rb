require 'helper'
require 'guardian/bucket'

describe Guardian::Bucket do
  describe '.by_name' do
    let(:bucket_one) { stub(:bucket_one, name: 'one') }
    let(:bucket_two) { stub(:bucket_two, name: 'two') }
    let(:buckets)    {[ bucket_one, bucket_two ]}

    it 'returns the bucket of the given name' do
      described_class.by_name('one', buckets).should eq(bucket_one)
    end
  end

  describe '.enqueue_processing_new_logs' do
    let(:buckets) {[ stub(:bucket, name: 'one'),
                     stub(:bucket, name: 'two') ]}
    let(:queue)   { stub :queue, enqueue: nil }

    it 'enqueues a job for each bucket' do
      queue.should_receive(:enqueue)
        .with('Guardian::Bucket.process_new_logs', 'one')
      queue.should_receive(:enqueue)
        .with('Guardian::Bucket.process_new_logs', 'two')
      queue.should_receive(:enqueue).never
      described_class.enqueue_processing_new_logs(buckets, queue)
    end
  end

  describe '.process_new_logs' do
    let(:bucket)   { stub(:bucket, name: 'bucket',
                                   process_new_logs_since: nil) }
    let(:buckets)  { stub(:buckets, by_name: bucket) }
    let(:log)      { stub(:log, last_log_file_for_bucket: log_file) }
    let(:log_file) { stub :log_file }
    subject {
      described_class.process_new_logs('bucket', buckets, log)
    }

    it 'finds last log file' do
      log.should_receive(:last_log_file_for_bucket).with('bucket')
      subject
    end

    it 'finds named bucket' do
      buckets.should_receive(:by_name).with('bucket')
      subject
    end

    it 'finds new log files' do
      bucket.should_receive(:process_new_logs_since).with(log_file, log)
      subject
    end
  end

  describe '#process_new_logs_since' do
    let(:aws)         { stub(:aws, files_for_bucket_since: files) }
    let(:files)       {[ stub(:file_one), stub(:file_two) ]}
    let(:log_file)    { stub(:log_file) }
    let(:log)         { stub(:log, create: nil) }
    let(:queue)       { stub :queue, enqueue: nil }
    let(:bucket)      { described_class.new(bucket_name) }
    let(:bucket_name) { stub(:bucket_name) }
    let(:logger)      { stub(:logger, puts: nil) }
    subject { bucket.process_new_logs_since(log_file, log, aws, queue, logger) }

    it 'logs log file fetching' do
      logger.should_receive(:puts)
        .with("Fetching logs bucket: #{bucket_name} since: #{log_file}")
      subject
    end

    it 'finds new log files' do
      aws.should_receive(:files_for_bucket_since).with(bucket, log_file)
      subject
    end

    it 'creates each log' do
      log.should_receive(:create).with(bucket_name, files[0])
      log.should_receive(:create).with(bucket_name, files[1])
      subject
    end

    it 'enqueues a job for each bucket' do
      queue.should_receive(:enqueue)
        .with('Guardian::Bucket.process_log_file', bucket_name, files[0])
      queue.should_receive(:enqueue)
        .with('Guardian::Bucket.process_log_file', bucket_name, files[1])
      subject
    end
  end

  describe '.process_log_file' do
    let(:bucket)   { stub(:bucket, name: 'bucket', process_log_file: nil) }
    let(:buckets)  { stub(:buckets, by_name: bucket) }
    let(:log_file) { stub :log_file }
    subject { described_class.process_log_file(bucket, log_file, buckets) }

    it 'finds named bucket' do
      buckets.should_receive(:by_name).with(bucket)
      subject
    end

    it 'passes the log file to the named bucket' do
      bucket.should_receive(:process_log_file).with(log_file)
      subject
    end
  end

  describe '#process_log_file' do
    let(:aws)      { stub(:aws, read_file_from_bucket: nil) }
    let(:log_file) { stub(:log_file) }
    let(:request)  { stub(:request, record_log_line: nil) }
    let(:logger)   { stub(:logger, puts: nil) }
    let(:bucket)   { described_class.new }
    subject { bucket.process_log_file(log_file, aws, request, logger) }

    it 'logs log file processing' do
      logger.should_receive(:puts).with("Processing: #{log_file}")
      subject
    end

    it 'records a request for each log line' do
      aws.stub(:read_file_from_bucket).with(bucket, log_file)
        .and_yield("one")
        .and_yield("two\n")
        .and_yield("three")
      request.should_receive(:record_log_line_from_log_file)
        .with(log_file, "onetwo\n")
      request.should_receive(:record_log_line_from_log_file)
        .with(log_file, "three")
      subject
    end

    it 'marks log as processed'
  end
end
