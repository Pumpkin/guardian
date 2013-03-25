require 'helper'
require 'database_helper'
require 'log'
require 'queue_classic'

describe Guardian::Log do
  describe '.last_log_file' do
    it 'returns last log file' do
      Guardian::Log.create('first')
      Guardian::Log.create('last')
      Guardian::Log.last_log_file.should eq('last')
    end

    it 'returns nil when no logs exists' do
      Guardian::Log.last_log_file.should be_nil
    end
  end

  describe '.create' do
    let(:log_file) { 'log_file' }

    it 'inserts an unprocessed log file' do
      Guardian::Log.create(log_file)
      row = Guardian::Database.execute('SELECT * FROM logs')

      row.should_not be_nil
      row['log_file'].should eq(log_file)
      row['processed'].should eq('f')
    end

    it 'returns the created log' do
      log = Guardian::Log.create(log_file)
      log.should_not be_nil
      log.id.should_not be_nil
      log.log_file.should eq(log_file)
    end
  end

  describe '.find' do
    let(:log) { Guardian::Log.create('log_file') }
    subject   { Guardian::Log.find(log.id) }

    it 'finds a log file by id' do
      subject.should eq(log)
    end
  end
end
