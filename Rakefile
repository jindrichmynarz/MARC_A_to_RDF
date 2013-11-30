#!/usr/bin/rake

require "rubygems"
require "nokogiri"
require "open-uri"
require "socket"
require "sparql/client"
require "timeout"

desc "Parse the XML configuration" 
task :parse_config do
  config = Nokogiri::XML(File.open(File.join("etc", "config.xml")))
  @config = config.xpath("/config").first
end

desc "Transform XML input into RDF/XML using XSLT"
task :xslt, [:input] => :parse_config do |t, args|
  raise "Please provide path to the input XML file "\
        "by using: rake xslt[path/to/file]" unless args[:input]
  raise "File #{args[:input]} doesn't exist." unless File.exists? args[:input]
  input = args[:input]
  input_size = sprintf("%.2f", File.size(input).to_f / 2**20).to_f
  available_ram = `ps -Ao rss=`.split.map(&:to_i).inject(&:+).to_f / 2**10
  recommended_heap_size = (input_size * 5).round
  raise "It is recommended to run the script on a machine with more RAM. "\
        "Recommended RAM is #{recommended_heap_size} MB, "\
        "while your RAM is #{available_ram.round} MB. "\
        "You can force the transformation using the force=true."\
        unless (available_ram > recommended_heap_size) || (ENV.key? "force")
  xmx = recommended_heap_size > 512 ? recommended_heap_size : 512
  saxon_path = @config.xpath("deps/dep[@name = 'saxon']/path/text()")
  raise "Please provide path to Saxon JAR file in #{File.join("etc", "config.xml")} "\
        "using <saxonPath>path/to/saxon</saxonPath>" unless saxon_path
  cmd = "java -Xmx#{xmx}m -jar #{saxon_path} +config=#{File.join("etc", "config.xml")} " +
    "-xsl:MARC_A_to_RDF.xsl -s:#{input} -o:#{File.join("tmp", "output.rdf")}"
  `#{cmd}`
  puts "XSL transformation done."
end

namespace :fuseki do
  desc "Check if the Fuseki server is running"
  task :check_running do
    raise "Fuseki server isn't running" unless server_running?
  end

  desc "Converts RDF/XML output of XSLT into NTriples for faster loading into TDB"
  task :convert_data => :jena_home do
    riot = File.join(@jena_home, "bin", "riot")
    rdfxml = File.join("tmp", "output.rdf")
    ntriples = File.join("tmp", "output.nt")
    unless File.exists? ntriples 
      `#{riot} #{rdfxml} > #{ntriples}`
      puts "#{rdfxml} converted to #{ntriples}"
    end
  end

  desc "Delete all data in Fuseki"
  task :drop => :get_config do
    `java -cp #{@fuseki_path} tdb.tdbupdate --loc db "DROP ALL"`
    # Restart Fuseki server so that DROP takes effect. 
    Rake::Task["fuseki:restart"].invoke
    puts "Fuseki server dropped all data."
  end

  desc "Dump data to a file"
  task :dump => :get_config do
    output_path = File.join("tmp", "tdb_dump.nt")
    `java -cp #{@fuseki_path} tdb.tdbdump --loc db > #{output_path}` 
    puts "Data dumped to #{output_path}."
  end

  desc "Get Fuseki configuration"
  task :get_config => [:jena_home, :fuseki_port, :fuseki_path, :named_graph]

  desc "Get path to Fuseki home directory"
  task :fuseki_home => "rake:parse_config" do
    @fuseki_home = get_home_path "fuseki"
  end

  desc "Get path to Fuseki JAR file"
  task :fuseki_path => :fuseki_home do
    @fuseki_path = File.join(@fuseki_home, "fuseki-server.jar")
    raise "JAR file on #{@fuseki_path} doesn't exist." unless File.exists? @fuseki_path
  end

  desc "Get port on which to run Fuseki"
  task :fuseki_port => "rake:parse_config" do
    @fuseki_port = @config.xpath("deps/dep[@name = 'fuseki']/port/text()").first.to_s.to_i
  end

  desc "Get Jena home directory"
  task :jena_home => "rake:parse_config" do
    @jena_home = get_home_path "jena"
  end

  desc "Load data into Fuseki SPARQL server"
  task :load => [:convert_data, :get_config] do
    data_path = File.join("tmp", "output.nt")
    # -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=30 -XX:+UseG1GC -Xmx16g 
    `java -cp #{@fuseki_path} tdb.tdbloader --loc db --graph #{@named_graph} #{data_path}`
    puts "Data loaded into Fuseki"
  end

  desc "Create named graph URI"
  task :named_graph => "rake:parse_config" do
    base_uri = @config.xpath("scheme/namespace/text()").first.to_s
    dataset_name = @config.xpath("scheme/conceptSchemeLabel/text()").first.to_s
    dataset_path = "dataset/" + URI::encode(dataset_name.downcase.gsub("\s", "-"))
    @named_graph = base_uri + dataset_path
  end

  desc "Purge completely all TDB files"
  task :purge do
    `rm -rf db/*`
    puts "All TDB files removed."
  end

  desc "Restart the Fuseki server"
  task :restart => [:stop, :start]

  desc "Start Fuseki SPARQL server"
  task :start => :get_config do
    puts "Starting the Fuseki server..."
    raise "Fuseki server already running" if server_running?
    raise "Port #{@fuseki_port} is not available, choose another one." unless port_available? @fuseki_port
    fuseki_config_path = File.join("etc", "fuseki.ttl")
    raise "Fuseki configuration at #{fuseki_config_path} doesn't exist." unless File.exists? fuseki_config_path
    
    # -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=30 -XX:+UseG1GC -Xmx4g 
    cmd = "java -server -jar #{@fuseki_path} --config #{fuseki_config_path} --home #{@fuseki_home} "\
          "--port #{@fuseki_port} --update"
    pid = fork { exec cmd }
    Process.detach pid  # Detach the pid
    write_pid pid       # Keep track of the pid
    sleep 5             # Let Fuseki take a deep breath before sending data in
    puts "Fuseki server started on <http://localhost:#{@fuseki_port}>."
  end

  desc "Stop the Fuseki server"
  task :stop => :check_running do
    puts "Stopping the Fuseki server..."

    parent_pid = read_pid
    child_pids = get_child_pids parent_pid
    pids = [parent_pid] + child_pids
    begin
      pids.each { |pid| Process.kill(:SIGTERM, pid) }
      sleep 5 # Wait for some time to free Fuseki port
      puts "Stopped"
      File.delete pid_path
    rescue StandardError => e
      puts "Failed"
      puts e.inspect
    end
  end
 
  def get_child_pids(parent_pid)
    # Source: http://t-a-w.blogspot.com/2010/04/how-to-kill-all-your-children.html
    descendants = Hash.new{ |ht,k| ht[k] = [k] }
    Hash[*`ps -eo pid,ppid`.scan(/\d+/).map{ |x| x.to_i }].each{ |pid, ppid|
      descendants[ppid] << descendants[pid]
    }
    descendants[parent_pid].flatten - [parent_pid]
  end

  def get_home_path(dependency)
    dep_home = ENV["#{dependency.upcase}_HOME"] ||
      @config.xpath("deps/dep[@name = '#{dependency}']/home/text()").first
    raise %Q{Please specify the home directory for #{dependency} by using
             <dep name=\"#{dependency}\">
               <home>#{File.join("path", "to", dependency, "home")}</home>
             </dep>} unless dep_home
    missing_error = "Directory #{dep_home}, to which #{dependency.capitalize} home is set, doesn't exist."
    raise missing_error unless File.directory? dep_home
    dep_home
  end

  def pid_path
    File.join("tmp", "fuseki.pid")
  end

  def port_available?(port, seconds = 1)
    Timeout::timeout(seconds) do
      begin
        TCPSocket.new("127.0.0.1", port).close
        false
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        true
      end
    end
  rescue Timeout::Error
    true
  end

  def read_pid
    File.read(pid_path).to_i
  end

  def server_running?
    if File.exist? pid_path
      pid = read_pid
      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
        return false
      end
    else
      false
    end
  end

  def write_pid(pid)
    File.open(pid_path, "w") { |f| f.write(pid) }
  end
end

namespace :sparql do
  desc "Establish connection to SPARQL Update endpoint"
  task :connect => ["fuseki:fuseki_port", "fuseki:named_graph"] do
    endpoint_url = "http://localhost:#{@fuseki_port}/MARC21A/update"
    @sparql = SPARQL::Client.new endpoint_url
  end

  desc "Enrich dataset with inferred triples using SPARQL Update"
  task :enrich => :connect do
    file_names = Dir[File.join("queries", "enrichment", "*.rq")]
    file_names.each do |file_name|
      @sparql.update(add_graph(File.read(file_name)))
    end
  end

  # Adds named graph URI to SPARQL queries
  def add_graph(query_template)
    query_template.gsub(/\?graph/i, "<#{@named_graph}>")
  end
end
