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
      log_line = LogLine.parse(raw_log_line, logger)
      return unless log_line
      Database.execute(CREATE_STATEMENT, log_file, log_line.bucket,
                                                   log_line.time,
                                                   log_line.operation,
                                                   log_line.key,
                                                   log_line.http_status,
                                                   log_line.bytes_sent,
                                                   log_line.referrer)
    rescue PG::Error => e
      # TODO: Better error message
      logger.puts "#{e.message} #{raw_log_line}".gsub("\n", '[\n]')
    end
  end

  class LogLine
    EMPTY   = '-'
    DATE    = /\[[^\]]+\]/
    QUOTED  = /"[^"]+"/
    SIMPLE  = /\S+/
    SCANNER = %r{
      ^(?<bucket_owner>#{SIMPLE})\s
      (?<bucket>#{SIMPLE})\s
      (?<time>#{DATE})\s
      (?<remote_ip>#{SIMPLE})\s
      (?<requestor>#{SIMPLE})\s
      (?<requestor_id>#{SIMPLE})\s
      (?<operation>#{SIMPLE})\s
      (?<key>#{SIMPLE})\s

      # A request URI may contain a quote. That makes this more
      # complicated than a simple quoted string.
      (?<request_uri>#{EMPTY}|#{SIMPLE}\s#{SIMPLE}\s#{SIMPLE})\s

      (?<http_status>#{SIMPLE})\s
      (?<error_code>#{SIMPLE})\s
      (?<bytes_sent>#{SIMPLE})\s
      (?<object_size>#{SIMPLE})\s
      (?<total_time>#{SIMPLE})\s
      (?<turn_around_time>#{SIMPLE})\s
      (?<referrer>#{QUOTED})\s
      (?<user_agent>#{QUOTED})\s
      (?<version_id>#{SIMPLE}).*$
    }x

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

    def self.parse line, logger
      match = SCANNER.match(line)
      unless match
        log_unparsable_line(line, logger)
        return
      end

      new(bucket:      match[:bucket],
          time:        parse_time(match[:time]),
          operation:   match[:operation],
          key:         parse_nullable(match[:key]),
          http_status: match[:http_status],
          bytes_sent:  parse_nullable(match[:bytes_sent]),
          referrer:    parse_nullable(parse_quoted(match[:referrer])))
    end

    # Borrowed from request-log-analyzer
    # https://github.com/wvanbergen/request-log-analyzer/blob/master/lib/request_log_analyzer/file_format/amazon_s3.rb#L48-L55
    MONTHS = {'Jan' => '01', 'Feb' => '02', 'Mar' => '03', 'Apr' => '04', 'May' => '05', 'Jun' => '06',
              'Jul' => '07', 'Aug' => '08', 'Sep' => '09', 'Oct' => '10', 'Nov' => '11', 'Dec' => '12' }

    def self.parse_time value
      DateTime.parse("#{value[8,4]}#{MONTHS[value[4,3]]}#{value[1,2]}#{value[13,2]}#{value[16,2]}#{value[19,2]}",
                     '%Y%m%d%H%M%S')
    end

    def self.parse_nullable value
      value == '-' ? nil : value
    end

    def self.parse_quoted value
      value[1...-1]
    end

    def self.log_unparsable_line line, logger
      # TODO: Better error message
      logger.puts "Parser Error: #{line}".gsub("\n", '[\n]')
    end
  end
end
