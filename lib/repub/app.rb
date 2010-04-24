require 'singleton'
require 'rubygems'
require 'launchy'
require 'repub/app/utility'
require 'repub/app/logger'
require 'repub/app/options'
require 'repub/app/profile'
require 'repub/app/filter'
require 'repub/app/pre_filters'
require 'repub/app/post_filters'
require 'repub/app/fetcher'
require 'repub/app/parser'
require 'repub/app/builder'

module Repub
  class App
    include Singleton
    
    # Mix-in actual functionality
    include Options, Profile, Fetcher, Parser, Builder, Logger

    def self.name
      File.basename($0)
    end
    
    def self.data_path
      data_path = File.join(File.expand_path('~'), '.repub')
      FileUtils.mkdir_p(data_path) unless File.exist?(data_path)
      data_path
    end
    
    def run(args)
      parse_options(args)
      
      log.level = options[:verbosity]
      log.info "Making ePub from #{options[:url]}"
      builder = build(parse(fetch))
      log.info "Saved #{builder.output_path}"
      
      Launchy::Browser.run(builder.document_path) if options[:browser]
    
    rescue RuntimeError => ex
      log.fatal "** ERROR: #{ex.to_s}\n#{ex.backtrace.join("\n")}"
    rescue Exception => ex
      log.fatal "** ERROR: #{ex.to_s}" unless ex.is_a? SystemExit
    end
  
  end
end
