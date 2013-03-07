require 'guardian/bucket'
require 'queue_classic'

module Guardian
  Queue       = QC.default_queue
  FailedQueue = QC::Queue.new 'queue_classic_failed_jobs'

  class Worker < QC::Worker
    def handle_failure(job, exception, logger = $stderr)
      # TODO: Better error message
      logger.puts exception.message
      FailedQueue.enqueue job[:method], *job[:args]
    end
  end
end
