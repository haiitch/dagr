
require 'json'
require 'pp'
require '../rb/dagr.rb'

include IPFS

nodes = Dir.glob("*.json").sort!

nodes.each {|file|
	# puts file
	begin
		txt = File.open(file).read
	rescue
		puts "Error reading file #{file}"
		exit 1
	end

	begin
		obj = JSON.parse(txt)
	rescue
		puts "Error parsing file #{file}"
		exit 1
	end

	dag = DAG.new(obj)

	puts file.ljust(20)[0..19] + " "+ dag.node.label.ljust(30)[0..29] + " "+ dag.cid
	
}
