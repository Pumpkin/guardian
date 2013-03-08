require 'helper'
require 'database_helper'
require 'guardian/request'

describe Guardian::LogLine do
  let(:logger)   { stub(:logger, puts: nil) }
  let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 "http://getcloudapp.com" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE

  describe '.record_log_line_from_log_file' do
    subject {
      Guardian::Request
        .record_log_line_from_log_file('logs/access_log', log_line, logger)
      Guardian::Database.execute('SELECT * FROM requests')
    }

    it 'records the request' do
      subject.should_not be_nil
      subject['log_file'].should    eq('logs/access_log')
      subject['bucket'].should      eq('bucket-name')
      subject['time'].should        eq('2013-02-03 15:23:01-05')
      subject['operation'].should   eq('REST.GET.OBJECT')
      subject['key'].should         eq('items/abc123/file.jpg')
      subject['http_status'].should eq('200')
      subject['bytes_sent'].should  eq('18946246')
      subject['referrer'].should    eq('http://getcloudapp.com')
    end

    context 'with an unparsable line' do
      let(:log_line) { 'unparsable' }

      it { should be_nil }

      it 'logs the error' do
        logger.should_receive(:puts).with("Parser Error: unparsable")
        subject
      end
    end

    context 'without a request uri' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg - 200 - 18946246 18946246 2243335 96 "http://getcloudapp.com" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE
      it { should_not be_nil }
    end
  end

  describe '.parse' do
    subject { Guardian::LogLine.parse(log_line, logger) }

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

    context 'with a request uri containing a quote' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg%2522 "GET items/abc123/file.jpg" HTTP/1.1" 403 AccessDenied 231 - 37 - "http://getcloudapp.com" "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6 (FlipboardProxy/0.0.5; +http://flipboard.com/browserproxy)" -
LINE
      it { should_not be_nil }
    end

    context 'with an unparsable line' do
      let(:log_line) { 'unparsable' }

      it 'logs the error' do
        logger.should_receive(:puts).with("Parser Error: unparsable")
        subject
      end
    end

    context 'without a request uri' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg - 200 - 18946246 18946246 2243335 96 "http://getcloudapp.com" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE
      it { should_not be_nil }
    end

    context 'with an empty, quoted referrer' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 "-" "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE
      it 'has no referrer' do
        subject.referrer.should be_nil
      end
    end

    context 'without a referrer' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 - "Mozilla/5.0 (Linux; U; Android 4.1.2; en-gb; GT-I9300 Build/JZO54K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30" -
LINE
      it { should_not be_nil }
    end

    context 'without a user agent' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 "http://getcloudapp.com" - -
LINE
      it { should_not be_nil }
    end

    context 'with a user agent containing a quote' do
      let(:log_line) { <<LINE }
abc123 bucket-name [03/Feb/2013:20:23:01 +0000] 8.8.8.8 def456 ghi789 REST.GET.OBJECT items/abc123/file.jpg "GET /f.cl.ly/items/abc123/file.jpg?AWSAccessKeyId=ACCESSKEY&Expires=1359926569&Signature=SIGNATURE&response-content-disposition=attachment HTTP/1.1" 200 - 18946246 18946246 2243335 96 "http://getcloudapp.com" ""User Agent"" -
LINE
      it { should_not be_nil }
    end
  end
end
