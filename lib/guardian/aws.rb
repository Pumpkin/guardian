require 'aws/s3'

module Guardian
  class AWS
    attr_reader :bucket_name, :access, :secret

    def initialize bucket_name, access, secret
      @bucket_name = bucket_name
      @access      = access
      @secret      = secret
    end

    def self.files_for_bucket_since bucket, marker
      new(bucket.name, bucket.access, bucket.secret).files_since(marker)
    end

    def self.read_file_from_bucket bucket, file, &block
      new(bucket.name, bucket.access, bucket.secret).read_file(file, &block)
    end

    def files_since marker
      s3.client.list_objects(bucket_name: bucket_name,
                             prefix:      'logs/access_log',
                             marker:      marker)
               .contents
               .map {|object| object[:key] }
    end

    def read_file file, &block
      s3.buckets[bucket_name].objects[file].read(&block)
    end

    def s3
      ::AWS::S3.new(access_key_id: access, secret_access_key: secret)
    end
  end
end
