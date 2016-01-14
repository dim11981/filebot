$LOAD_PATH << "#{File.dirname(__FILE__)}/../"

require 'lib/logutility'

log_path = "#{File.dirname(__FILE__)}/../log/#{ENV['COMPUTERNAME']}-filebot.log"
log = Filebot::Log.instance
log.set_to(log_path)

log.write(self, 'info', 'enter (вход)')
log.write(self, 'info', 'testing (тестирую)')
log.write(self, 'info', 'exit (выход)')

log.close