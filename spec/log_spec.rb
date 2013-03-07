require 'helper'
require 'database_helper'
require 'log'
require 'queue_classic'

describe Guardian::Log do
  describe '.last_log_file_for_bucket' do
    let(:bucket) { 'bucket' }
    before do
      Guardian::Log.create(bucket, 'first')
      Guardian::Log.create(bucket, 'last')
    end

    it 'returns last log file for bucket' do
      Guardian::Log.last_log_file_for_bucket(bucket).should eq('last')
    end

    it 'returns nil for an unknown bucket' do
      Guardian::Log.last_log_file_for_bucket('unknown').should be_nil
    end
  end

  describe '.create' do
    let(:bucket)   { 'bucket' }
    let(:log_file) { 'log_file' }

    it 'inserts an unprocessed log file for a bucket' do
      Guardian::Log.create(bucket, log_file)
      row = Guardian::Database.execute('SELECT * FROM logs')

      row.should_not be_nil
      row['log_file'].should eq(log_file)
      row['bucket'].should eq(bucket)
      row['processed'].should eq('f')
    end

    it 'returns the created log' do
      log = Guardian::Log.create(bucket, log_file)
      log.should_not be_nil
      log.id.should_not be_nil
      log.bucket.should eq(bucket)
      log.log_file.should eq(log_file)
    end
  end

  describe '.find' do
    let(:log) { Guardian::Log.create('bucket', 'log_file') }
    subject   { Guardian::Log.find(log.id) }

    it 'finds a log file by id' do
      subject.should eq(log)
    end
  end
end
