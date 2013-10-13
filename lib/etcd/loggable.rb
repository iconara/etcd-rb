module Etcd::Loggable
  def logger(level=Logger::WARN)
    @logger ||= reset_logger!(level)
  end

  def reset_logger!(level=Logger::WARN)
    @logger = begin
      log       = Logger.new(STDOUT)
      log.level = level
      log
    end
  end
end