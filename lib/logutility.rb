require 'logger'
require 'singleton'

require 'lib/filebotns'

# Filebot::Log class
# supports log operations
class Filebot::Log
  include Singleton

  LOG_ENCODING = 'utf-8'
  MSG_ENCODING = 'utf-8'

  # initialization
  def initialize
    @log_mon = Monitor.new
  end

  # load log env
  def set_to(path)
    @path = path
    @logger = Logger.new(path,7,104857600)
    @logger.level = Logger::DEBUG
  end

  # write log
  def write(program,severity,message)
    @log_mon.synchronize {
      msg = message.encode(LOG_ENCODING,MSG_ENCODING,{ invalid: :replace, undef: :replace })
      case severity
        when 'error' then @logger.error(program) { msg }
        when 'debug' then @logger.debug(program) { msg }
        when 'info' then @logger.info(program) { msg }
        when 'warn' then @logger.warn(program) { msg }
        else
          @logger.unknown(program) { msg }
      end
    }
  end

  # close log
  def close
    @logger.close if @logger
  end
end
