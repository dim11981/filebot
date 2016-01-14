require 'fiddle'
require 'fiddle/import'

# Kernel32Lib module
# supports kernel32 WinAPI functions
module Kernel32Lib
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  extern 'void* CreateFile(char*,unsigned long,unsigned long,void*,unsigned long,unsigned long,void*)'
  extern 'int CloseHandle(void*)'
  extern 'int GetFileInformationByHandle(void*,void*)'
  extern 'int FileTimeToSystemTime(void*,void*)'

  # FileTimeToSystemTime
  def self.ftime_to_systime(ftime)
    str_time = '0'*50
    Kernel32Lib.FileTimeToSystemTime(ftime,str_time)
    systime_arr = str_time.unpack('S8')
    Time.new(systime_arr[0],systime_arr[1],systime_arr[3],systime_arr[4],systime_arr[5],systime_arr[6],systime_arr[7])
  end

  # GetFileInformationByHandle
  def self.get_file_info_by_handle(path)
    str_file_info = '0'*100
    handle = Kernel32Lib.CreateFile(path,1,3,0,3,48,0)
    Kernel32Lib.GetFileInformationByHandle(handle,str_file_info)
    Kernel32Lib.CloseHandle(handle)

    file_info_arr = str_file_info.unpack('I13')
    file_info = {
        file_path: path,
        attr: file_info_arr[0],
        volume_sn: file_info_arr[7],
        size_high: file_info_arr[8],
        size_low: file_info_arr[9],
        num_links: file_info_arr[10],
        index_high: file_info_arr[11],
        index_low: file_info_arr[12]
    }
    file_info[:cr_time] = Kernel32Lib.ftime_to_systime(file_info_arr[1,2].pack('I2'))
    file_info[:ac_time] = Kernel32Lib.ftime_to_systime(file_info_arr[3,4].pack('I2'))
    file_info[:wr_time] = Kernel32Lib.ftime_to_systime(file_info_arr[5,6].pack('I2'))

    file_info
  end
end
