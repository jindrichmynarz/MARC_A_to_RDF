#!/usr/bin/rake

require "rubygems"
require "nokogiri"

desc "Transform XML into RDF/XML using XSLT"
task :xslt => :parse_config do
  raise "Please provide path to the input XML file"\
        "by using input=path/to/file command-line parameter." unless ENV.key? "input"
  input = ENV["input"]
  input_size = (File.size(input).to_f / 2**20).round(2)
  available_ram = `ps -Ao rss=`.split.map(&:to_i).inject(&:+).to_f / 2**10
  recommended_heap_size = (input_size * 5).round
  raise "It is recommended to run the script on a machine with more RAM. "\
        "Recommended RAM is #{recommended_heap_size} MB, "\
        "while your RAM is #{available_ram.round} MB. "\
        "You can force the transformation using the force=true."\
        unless (available_ram > recommended_heap_size) || (ENV.key? "force")
  xmx = recommended_heap_size > 512 ? recommended_heap_size : 512
  saxon_path = @config.xpath("/config/saxonPath/text()") 
  raise "Please provide path to Saxon JAR file in config.xml "\
        "using <saxonPath>path/to/saxon</saxonPath>" unless saxon_path
  `java -Xmx#{xmx}m -jar #{saxon_path} +config=config.xml -xsl:MARC_A_to_RDF.xsl -s:#{input} -o:output.rdf`
  puts "XSL transformation done."
end

task :parse_config do
  @config = Nokogiri::XML(File.open("config.xml"))
end

namespace :fuseki do
  desc "Start Fuseki SPARQL server"
  task :init => :fuseki_path do
  end

  desc "Load data into Fuseki SPARQL server"
  task :load => :fuseki_path do
  end

  desc "Get path to Fuseki JAR file"
  task :fuseki_path => "rake:parse_config" do
    @fuseki_path = @config.xpath("/config/fusekiPath/text()")
  end
end
