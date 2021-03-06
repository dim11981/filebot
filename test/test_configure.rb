require(File.expand_path('../../lib/configure',__FILE__))

config_path = "#{File.dirname(__FILE__)}/../conf/filebot.yml"
puts Filebot::Configuration.load_from(config_path)

seekdb_path = "#{File.dirname(__FILE__)}/../log/localhost-seekdb.sample.json"
@seekdb = Filebot::SeekDb.instance
@seekdb.load_from(seekdb_path)

puts
puts @seekdb['0-0-0']
