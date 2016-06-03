require 'kernel32lib/files'

# Filebot module
module Filebot
  # current version
  VERSION = '0.0.2'

  # get inode for Windows by path
  #
  #   @param path [String] Path to file
  #   @return [String] inode is a string kind of 'volume_serial_number-index_low-index_high'
  def self.inode(path)
    file_info = Kernel32Lib.get_file_information_by_handle(path)
    "#{file_info[:volume_serial_number]}-#{file_info[:file_index_low]}-#{file_info[:file_index_high]}"
  end
end