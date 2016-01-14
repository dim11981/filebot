require 'yaml/store'
require 'singleton'
require 'json'

require 'lib/filebotns'

# Filebot::Configuration module
# program configuration
class Filebot::Configuration
  # defaults
  #   block_size: 100000
  #   batch_size: 5000
  #   remove_file: true
  #   scan_delay: 120
  #   send_timeout: 10
  SETT_DEFAULTS = { block_size: 100000, batch_size: 5000, remove_file: true, scan_delay: 120, send_timeout: 10 }

  # load configuration
  def self.load_from(path)
    @path = path
    store = YAML::Store.new(path)
    store.transaction(true) {
      [ store['dirs'], store['hosts'], SETT_DEFAULTS.merge(store['settings']) ]
    }
  end
end

# Filebot::SeekDb class
# store seek position
class Filebot::SeekDb
  include Singleton

  # initialization
  def initialize
    @seek_db = {}
    @db_mon = Monitor.new
  end

  # load from file
  def load_from(path)
    @path = path
    File.readlines(path).each { |line|
      x = JSON.parse(line).to_h
      @seek_db[x['inode']] = x
    } rescue nil
  end

  # save seek data (in JSON) to file
  def dump
    @db_mon.synchronize {
      File.open(@path,'wt') { |file|
        @seek_db.each_value { |x|
          file.write(x.to_json)
          file.write("\n")
        }
      } rescue nil
    }
  end

  # set seek data by inode
  def []=(inode,args)
    @db_mon.synchronize {
      @seek_db[inode] = { inode: inode, path: args[0], pos: args[1] }
    }
  end

  # get seek position (or 0) by inode
  def pos(inode)
    @db_mon.synchronize {
      (@seek_db[inode][:pos] || 0).to_i
    }
  end

  # remove seek data by inode (when source file deleted)
  def delete_key(inode)
    @db_mon.synchronize {
      @seek_db.delete(inode) rescue nil
    }
  end

  # get seek data by inode
  def [](inode)
    @db_mon.synchronize {
      @seek_db[inode]
    }
  end
end
