require 'helper'
require 'database_helper'
require 'guardian/request'

describe Guardian::LogLine do
  let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 "http://getcloudapp.com" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE

  describe '.record_log_line_from_log_file' do
    it 'records the request' do
      Guardian::Request.record_log_line_from_log_file('logs/access_log',
                                                      log_line)
      row = Guardian::Database.execute('SELECT * FROM requests')

      row.should_not be_nil
      row['log_file'].should    eq('logs/access_log')
      row['bucket'].should      eq('bucket-name')
      row['time'].should        eq('2013-02-03 15:23:01-05')
      row['operation'].should   eq('REST.GET.OBJECT')
      row['key'].should         eq('items/abc123/file.jpg')
      row['http_status'].should eq('200')
      row['bytes_sent'].should  eq('18946246')
      row['referrer'].should    eq('http://getcloudapp.com')
    end
  end

  describe '.parse' do
    subject { Guardian::LogLine.parse(log_line) }

    it 'records bucket name' do
      subject.bucket.should eq('bucket-name')
    end

    it 'records access time' do
      expected = DateTime.new(2013, 2, 3, 20, 23, 1)
      subject.time.should eq(expected)
    end

    it 'records operation' do
      subject.operation.should eq('REST.GET.OBJECT')
    end

    it 'records key' do
      subject.key.should eq('items/abc123/file.jpg')
    end

    it 'records http status' do
      subject.http_status.should eq('200')
    end

    it 'records bytes sent' do
      subject.bytes_sent.should eq('18946246')
    end

    it 'records referrer' do
      subject.referrer.should eq('http://getcloudapp.com')
    end

    context 'without a key' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT - "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 "http://getcloudapp.com" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE
      it 'has no key' do
        subject.key.should be_nil
      end
    end

    context 'with no bytes sent' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT - "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - - 18946246 2243335 96 "http://getcloudapp.com" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE
      it 'has no key' do
        subject.bytes_sent.should be_nil
      end
    end

    context 'without a referrer' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 "-" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE
      it 'has no referrer' do
        subject.referrer.should be_nil
      end
    end
  end
end
