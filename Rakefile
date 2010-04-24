$:.unshift('lib')
require 'repub'
require 'bones'

task :default => 'test:run'

Bones {
  name 'repub'
  authors 'Dmitri Goutnik'
  email 'dg@invisiblellama.net'
  url 'http://rubyforge.org/projects/repub/'
  version Repub::VERSION
  # rubyforge.name 'repub'
  readme_file 'README.rdoc'
  exclude %w[tmp/ \.git \.DS_Store .*\.tmproj .*\.epub ^pkg/]
  # spec.opts << '--color'
  depend_on 'nokogiri'
  depend_on 'builder'
  depend_on 'chardet'
  depend_on 'launchy'
}
