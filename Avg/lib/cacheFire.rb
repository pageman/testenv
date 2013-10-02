#! env jruby
$LOAD_PATH << './lib'

require 'ruby-progressbar'
require 'logger'
require 'java'
require 'json'
require 'scour.rb'
require 'options.rb'
require 'linkpool.rb'     
require 'job.rb'         
require 'varnish.rb'
require 'standard.rb'
require 'targeted.rb'
require 'stats.rb'

java_import 'java.util.concurrent.FutureTask'
java_import 'java.util.concurrent.LinkedBlockingQueue'
java_import 'java.util.concurrent.ThreadPoolExecutor'
java_import 'java.util.concurrent.TimeUnit'


begin
  options = Options.new
  options.parse_options
       
                 url = options.config[:url]
                port = options.config[:port]
             threads = options.config[:threads].to_i
               links = options.config[:links].to_i


  # create the thread pool for the executor
  executor = ThreadPoolExecutor.new(threads, # core_pool_treads
                                   (threads * 3),     # max_pool_threads
                                   10,       # keep_alive_time
                                   TimeUnit::SECONDS,
                                   LinkedBlockingQueue.new )


  # setup global logging
  $log = Logger.new('cacheFire.log', 'daily')
  $log.datetime_format = "%Y-%m-%d %H:%M:%S"


  # Purge all links from the cache
  if options.config[:purge]
    puts 'Purging all links from cache'
    linkPool = LinkPool.new(options) 
    linkPool.purge 
  end


  # Scour Mode
  # crawl URL and generate $file.dat
  if options.config[:scour]
    Scour.new(options)
  end


  # Retrieve Mode
  # use the $filename.dat file or Redis to GET links from URL 
  if options.config[:retrieve]

  # setup the connection to the host
  h = PersistentHTTP.new(
     :name         => 'cacheFire',
     :pool_size    => 2048,
     :pool_timeout => 10,
     :warn_timeout => 0.25,
     :force_retry  => false,
     #:proxy_uri    => "http://www1.prod.nastygal.com",
     #:proxy_port   => 6081,
     :url          => url,
     :port         => port )

    linkPool = LinkPool.new(options) 
    linkPool.read 

    stats = Stats.new(options, linkPool)

    if options.config[:targeted]
      run_targeted(executor, threads, h, url, linkPool, options, stats)
    else
      run_standard(executor, links, threads, h, url, linkPool, options, stats)
    end

    # dump out the 404's from this run
    File.delete('404s.json') if File.exists?('404s.json')
    $stdout = File.open('path/to/file.txt', 'w')
    puts myArray.to_json

  end
ensure 
  executor.shutdown() if options.config[:retrieve]
  $log.close if $log
end
