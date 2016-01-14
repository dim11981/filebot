# coding: utf-8

require 'thread'
require 'socket'
require 'json'
require 'timeout'
require 'csv'

require 'lib/logutility'
require 'lib/filebotns'

# Filebot::FileSendServer class
class Filebot::FileSendServer
  # StopError class
  class StopError < Exception
  end

  # initialization
  def initialize(block_size)
    @block_q = SizedQueue.new(block_size)
    @seekdb = Filebot::SeekDb.instance
    @log = Filebot::Log.instance

    @net_send_thread_group = ThreadGroup.new
    @file_scan_thread_group = ThreadGroup.new
  end

  def load_seekdb(path)
    @seekdb.load_from(path)
  end

  def set_log(path)
    @log.set_to(path)
  end

  # parse line into hash by format (in configuration)
  def parse_line_to_format(line,file,path_item)
    tmp_hash = { message: line, filebot: { format_from: path_item['format'], path_from: file.path, size_from: file.size } }.merge(path_item['fields'] || {})
    case path_item['format']
      when 'log' then tmp_hash
      when 'csv' then
        csv_arr = CSV.parse_line(line,path_item['options'].reject { |k,_| k == :headers }) rescue []
        if csv_arr.size == 0
          tags = [tmp_hash['tags'].to_a]
          tags.push('_csvparsefailure')
          tmp_hash['tags'] = tags
        else
          res = []
          path_item['options'][:headers].each_with_index { |field_name,i| res << [field_name,csv_arr[i]] }
          if res.size < csv_arr.size
            res << [ 'tail_csv', csv_arr[res.size..csv_arr.size-1].join("\t") ]
          end
          tmp_hash = tmp_hash.merge(res.to_h)
        end
        tmp_hash
      else tmp_hash
    end
  end

  # run scan files into directory thread
  def run_file_scan(configuration_item)
    @file_scan_thread_group.add(
      Thread.new(configuration_item) { |path_item|
        Thread.current[:name] = 'file_scan'
        begin
          Thread.handle_interrupt(RuntimeError => :on_blocking) {
            loop {
              begin
                Thread.handle_interrupt(StopError => :immediate) {} if Thread.pending_interrupt?
                Dir.glob(path_item['path']) { |file_path|
                  Thread.handle_interrupt(StopError => :immediate) {} if Thread.pending_interrupt?
                  next unless File.mtime(file_path) <= (Time.now - path_item[:scan_delay].to_i)
                  inode = Filebot.inode(file_path)
                  @seekdb[inode] = [ file_path, 0 ]
                  File.open(file_path, 'rt', path_item['options']) { |file|
                    file.seek(@seekdb.pos(inode))
                    file.each { |line|
                      Thread.handle_interrupt(StopError => :immediate){} if Thread.pending_interrupt?
                      @seekdb[inode] = [ file.path, file.pos ]
                      line_hash = parse_line_to_format(line.encode({ invalid: :replace, undef: :replace }),file,path_item)
                      @block_q.enq(line_hash)
                      Thread.pass
                    }
                  }
                  if path_item[:remove_file] and @seekdb.pos(inode) == File.size(file_path)
                    File.delete(file_path) rescue nil
                    @seekdb.delete_key(inode)
                  end
                  Thread.pass
                }
                Thread.pass
              rescue StopError
                raise
              rescue => exc
                @log.write(self, 'error', exc.inspect)
                @log.write(self, 'debug', exc.backtrace.join("\n "))
                sleep(1)
              end
            }
          }
        rescue StopError
          @log.write(self, 'info', 'stop')
        rescue => exc
          @log.write(self, 'error', exc.inspect)
        ensure
          @seekdb.dump
        end
      }
    )
  end

  # push json-string into array (sending cache)
  def push_block_with_to_json(host_item,block_hash,batch_arr)
    tmp_hash = { host_to: host_item['host'], port_to: host_item['port'], format_to: 'json' }.merge(block_hash[:filebot] || {})
    block_hash[:filebot] = tmp_hash
    batch_arr.push(block_hash.to_json) rescue nil
  end

  # send batch of json-strings
  def puts_batch(host_item,batch_arr)
    begin
      client = TCPSocket.new(host_item['host'], host_item['port'])
      client.puts(batch_arr)
      batch_arr.clear
    rescue => exc
      @log.write(self, 'error', exc.inspect)
      @log.write(self, 'debug', exc.backtrace.join("\n  "))
      sleep(1)
    ensure
      client.close if client
    end if batch_arr.size > 0
  end

  # run network sending thread
  def run_net_send(configuration_item)
    @net_send_thread_group.add(
      Thread.new(configuration_item) { |host_item|
        Thread.current[:name] = 'net_send'
        begin
          batch_arr = []
          Thread.handle_interrupt(RuntimeError => :on_blocking) {
            loop {
              begin
                Thread.handle_interrupt(StopError => :immediate){} if Thread.pending_interrupt?
                host_item[:batch_size].to_i.times {
                  Thread.handle_interrupt(StopError => :immediate){} if Thread.pending_interrupt?
                  block = timeout(host_item[:send_timeout].to_i) { @block_q.deq }
                  push_block_with_to_json(host_item, block, batch_arr)
                } if batch_arr.size < host_item[:batch_size].to_i
                puts_batch(host_item, batch_arr)
                Thread.pass
              rescue Timeout::Error
                puts_batch(host_item, batch_arr)
              rescue StopError
                raise
              rescue => exc
                @log.write(self, 'error', exc.inspect)
                @log.write(self, 'debug', exc.backtrace.join("\n  "))
                sleep(1)
              end
            }
          }
        rescue StopError
          @log.write(self, 'info', 'stop')
        rescue => exc
          @log.write(self, 'error', exc.inspect)
        end
      }
    )
  end

  # stop worker
  def stop
    @file_scan_thread_group.list.each { |thread|
      puts(thread[:name] || '<unknown>')
      thread.raise(StopError,'stop') if thread.alive?
      thread.wakeup if thread.alive?
      thread.join
      puts "  #{thread.inspect}"
    }
    @net_send_thread_group.list.each { |thread|
      puts(thread[:name] || '<unknown>')
      thread.raise(StopError,'stop') if thread.alive?
      thread.wakeup if thread.alive?
      thread.join
      puts "  #{thread.inspect}"
    }
    @log.write(self, 'info', 'stop')
  end
end
