require 'fileutils'
require 'digest/sha1'
require 'uri'
require 'iconv'
require 'rubygems'

# Disable warnings from chardet
old_verbose = $VERBOSE
$VERBOSE = false
require 'UniversalDetector'
$VERBOSE = old_verbose

module Repub
  class App
    module Fetcher
    
      class FetcherException < RuntimeError; end

      def fetch
        FetcherSupport.new(options).fetch
      end
    
      AssetTypes = {
        :documents => %w[html htm],
        :stylesheets => %w[css],
        :images => %w[jpg jpeg png gif svg]
      }

      class FetcherSupport
        include Logger
        
        Downloaders = {
          :wget     => { :cmd => 'wget', :options => '--no-verbose --html-extension --span-hosts --convert-links --page-requisites --no-host-directories --no-directories --max-redirect=0' },
          :httrack  => { :cmd => 'httrack', :options => '-gBqQ -r2 +*.css +*.jpg -*.xml -*.html' }
        }
        
        def initialize(options)
          @options = options
          @downloader_path, @downloader_options = ENV['REPUB_DOWNLOADER'], ENV['REPUB_DOWNLOADER_OPTIONS']
          downloader =
            begin
              Downloaders[@options[:helper].to_sym] || Downloaders[:wget]
            rescue
              Downloaders[:wget]
            end
          log.debug "-- Using #{downloader[:cmd]} #{downloader[:options]}"
          @downloader_path ||= which(downloader[:cmd])
          @downloader_options ||= downloader[:options]
        end
        
        def fetch
          url = @options[:url]
          raise FetcherException, "empty URL" if !url || url.empty?
          begin
            /^https?:\/\/[-_.!~*'()a-zA-Z0-9;?:\@&=+\$,%#]+\/?/ =~ url
          rescue
            raise FetcherException, "invalid URL: #{url}"
          end
          Cache.for_url(url) do |cache|
            log.debug "-- Downloading into #{cache.path}"
            cmd = "#{@downloader_path} #{@downloader_options} #{url}"
            unless system(cmd) && !cache.empty?
              raise FetcherException, "Fetch failed."
            end
            unless cache.cached?
              preprocess cache
            end
          end
        end
        
        private
        
        def preprocess(cache)
          cache.assets[:documents].each do |file|
            log.info "Preprocessing #{file}"
            s = PreFilters.apply_filters(IO.read(file), @options)
            File.open(file, 'w') { |f| f.write(s) }
          end
        end

        def which(cmd)
          if !RUBY_PLATFORM.match('mswin')
            cmd = `/usr/bin/which #{cmd}`.strip
            raise FetcherException, "#{cmd}: helper not found." if cmd.empty?
          end
          cmd
        end
      end

      class Cache
        include Logger
        
        def self.root
          return File.join(App.data_path, 'cache')
        end
      
        def self.cleanup
          Dir.chdir(self.root) { FileUtils.rm_r(Dir.glob('*')) }
        rescue
          # ignore exceptions
        end
      
        attr_reader :url
        attr_reader :name
        attr_reader :path
        
        def self.for_url(url, &block)
          self.new(url).for_url(&block)
        end
      
        def for_url(&block)
          # Download stuff if not yet cached
          @cached = File.exist?(@path)
          unless @cached
            FileUtils.mkdir_p(@path) 
            begin
              Dir.chdir(@path) { yield self }
            rescue
              FileUtils.rm_r(@path)
              raise
            end
          else
            log.info "Using cached assets"
            log.debug "-- Cache is #{@path}"
          end
          self
        end
        
        def assets
          unless @assets
            # Enumerate assets
            Dir.chdir(@path) do
              @assets = {}
              AssetTypes.each_pair do |asset_type, file_types|
                @assets[asset_type] ||= []
                file_types.each do |file_type|
                  @assets[asset_type] << Dir.glob("*.#{file_type}")
                end
                @assets[asset_type].flatten!
              end
            end
          end
          @assets
        end

        def empty?
          Dir.glob(File.join(@path, '*')).empty?
        end
        
        def cached?
          @cached == true
        end
      
        private
      
        def initialize(url)
          @url = url
          @name = Digest::SHA1.hexdigest(@url)
          @path = File.join(Cache.root, @name)
          @assets = nil
        end
      end
      
    end
  end
end
