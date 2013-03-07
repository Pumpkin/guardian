require 'time'
require 'guardian/database'

module Guardian
  class Request
    CREATE_STATEMENT = <<-SQL
      INSERT INTO requests
      (log_file, bucket, time, operation, key, http_status, bytes_sent,
       referrer)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id
    SQL

    def self.record_log_line_from_log_file log_file, raw_log_line, logger = $stderr
      log_line = LogLine.parse(raw_log_line)
      Database.execute(CREATE_STATEMENT, log_file, log_line.bucket,
                                                   log_line.time,
                                                   log_line.operation,
                                                   log_line.key,
                                                   log_line.http_status,
                                                   log_line.bytes_sent,
                                                   log_line.referrer)
    rescue PG::Error => e
      # TODO: Better error message
      logger.puts "#{e.message} - #{raw_log_line}".gsub("\n", '[\n]')
    end
  end

  class LogLine
    DATE    = /\[([^\]]+)\]/
    QUOTED  = /"([^"]+)"/
    SIMPLE  = /(\S+)/
    SCANNER = /#{DATE}|#{QUOTED}|#{SIMPLE}/

    attr_accessor :bucket, :time, :operation, :key, :http_status,
                  :bytes_sent, :referrer

    def initialize options
      @bucket      = options[:bucket]
      @time        = options[:time]
      @operation   = options[:operation]
      @key         = options[:key]
      @http_status = options[:http_status]
      @bytes_sent  = options[:bytes_sent]
      @referrer    = options[:referrer]
    end

    def self.parse line
      parsed = line.scan(SCANNER).flatten.compact
      new(bucket:      parsed[1],
          time:        parse_time(parsed[2]),
          operation:   parsed[6],
          key:         parse_nullable(parsed[7]),
          http_status: parsed[9],
          bytes_sent:  parse_nullable(parsed[11]),
          referrer:    parse_nullable(parsed[15]))
    end

    # Borrowed from request-log-analyzer
    # https://github.com/wvanbergen/request-log-analyzer/blob/master/lib/request_log_analyzer/file_format/amazon_s3.rb#L48-L55
    MONTHS = {'Jan' => '01', 'Feb' => '02', 'Mar' => '03', 'Apr' => '04', 'May' => '05', 'Jun' => '06',
              'Jul' => '07', 'Aug' => '08', 'Sep' => '09', 'Oct' => '10', 'Nov' => '11', 'Dec' => '12' }

    def self.parse_time value
      DateTime.parse("#{value[7,4]}#{MONTHS[value[3,3]]}#{value[0,2]}#{value[12,2]}#{value[15,2]}#{value[18,2]}",
                     '%Y%m%d%H%M%S')
    end

    def self.parse_nullable value
      value == '-' ? nil : value
    end
  end
end
