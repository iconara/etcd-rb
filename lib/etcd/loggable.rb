module Etcd::Loggable
  def logger
    @logger ||= reset_logger!
  end

  def reset_logger!
    @logger = begin
      log       = Logger.new(STDOUT)
      log.level = Logger::DEBUG
      log
    end
  end
end