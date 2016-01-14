$LOAD_PATH << "#{File.dirname(__FILE__)}/../"

require 'lib/filebotns'
require 'lib/kernel32'

puts Kernel32Lib.get_file_info_by_handle(File.expand_path(__FILE__))

puts "inode: #{Filebot.inode(File.expand_path(__FILE__))}"