require 'lib/kernel32'

# Filebot module
module Filebot
  # current version
  VERSION = '0.0.1'

  # get inode for Windows by path
  #
  #   @param path [String] Path to file
  #   @return [String] inode is a string kind of 'volume_serial_number-index_low-index_high'
  def self.inode(path)
    file_info = Kernel32Lib.get_file_info_by_handle(path)
    "#{file_info[:volume_sn]}-#{file_info[:index_low]}-#{file_info[:index_high]}"
  end
end