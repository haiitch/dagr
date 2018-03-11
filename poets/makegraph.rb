
require 'json'
require 'pp'
require '../rb/dagr.rb'

include IPFS

# api endpoint specified as parameter to the constructor.
# subsequent instances of the client will keep the last used endpoint
# as the default. if none is specified, it will use standard IPFS defaults.
c = IPFS::Client.new("http://127.0.0.1:45001/api/v0")

start_time = Time.now

nodes = Dir.glob("*.json").sort!

igraph = IPFS::DAGObject.new
inodes = IPFS::DAGObject.new 
iedges = IPFS::DAGObject.new
iadj   = IPFS::DAGObject.new 
iview  = IPFS::DAGObject.new 

gnodes = {}
gedges = {}
nodecount = 0

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

	nodecount=nodecount+1
	nid = nodecount.hex
	gnodes[nodecount]=dag 
	puts file.ljust(20)[0..19] + " "+nid+" "+ dag.node.label.ljust(34)[0..33] + " "+ dag.cid

	inodes.add_link(nid, dag.cid)
}

graphnode = IPFS::DAG.new({ name: "Sample graph", 
							author: "@h@social.coop", 
							nodecount: nodecount, 
							edgecount: 0,
							adjentrybytes: 4
						})


# attempt to build this undirected graph as a mutable
# data structure on top of the dag
#
#  (01)----(02)----(04)
#     \    /  \
#      (03)    `---(05)
#


# trying out different adjacency and incidence lists
# to see which perform better, and what's the optimal
# number of nodes for a subjective mutable graph
adjlist = {
	"0001" => ["0002", "0003"],
	"0002" => ["0001", "0003", "0004", "0005"],
	"0003" => ["0001", "0002"],
	"0004" => ["0002"],
	"0005" => ["0002"]
}

adjlist = {
	1 => [     2,     3],
	2 => [     1,     3,    4,    5],
	3 => [     1,     2],
	4 => [     2],
	5 => [     2]
}

# e1 ( a: n01 n02,  b: n02 n01)
# e2 ( a: n02 n03,  b: n03 n02)
# e3 ( a: n01 n03,  b: n03 n01)
# e4 ( a: n02 n04,  b: n04 n02)
# e5 ( a: n02 n05,  b: n05 n02)
incidence = {
	:e1 => [ [1,2], [2,1] ],
	:e2 => [ [2,3], [3,3] ],
	:e3 => [ [1,3], [3,1] ],
	:e4 => [ [2,4], [4,2] ],
	:e5 => [ [2,5], [5,2] ]
}

adjlist = {}
count = 1
linkspernode = 10

puts "Making adjacency list for #{count} nodes"

#n = [] ; 0.upto(linkspernode) { n.push(0xffff) }

n = [ "ffff"* linkspernode ]


#0.upto(count) {|count|
# n = []
# 0.upto(linkspernode) { n.push((rand*count).round) }
#	adjlist[count]=n 
#}


#gnodes.each {|alnk,adag|
	# puts alnk.hex
	# puts adag
	# puts "."*79
#	iadj.add_link( alnk.hex, DAG.new( n ) )
#}
1.upto(count) {|idx|
	iadj.add_link( idx.hex, DAG.new( n ) )
}



igraph.add_link( "graph",     graphnode.cid  )
igraph.add_link( "adjacency", iadj.cid       )
igraph.add_link( "nodes",     inodes.cid     )
igraph.add_link( "edges",     iedges.cid     )
igraph.add_link( "view",      iview.cid      )



puts igraph.cid

elaps = Time.now - start_time
puts "Elapsed time: #{elaps}"
puts "Nodes per second: #{count*1.0/elaps}"
puts 

start_time = Time.now 
puts "Publishing..."
puts "#{igraph.url}"

#pp igraph.client 


ipnscid = c.publish("graphsample", igraph.cid)
puts igraph.client.url( ipnscid, ipns: true )



# pp igraph.client.cache
# $ ipfs key gen --type=rsa --size=4096 graphsample
# QmVUo5J8N5Qq7YNQCaYbh3mHZcacsSeY7CrrDLdpth1jYA
# 
# $ ipfs name publish --key=graphsample QmPr4ozRykRZKtfDKNqwnqZomuqFuoYzH2TPnL1pPfF8zw
# Published to QmVUo5J8N5Qq7YNQCaYbh3mHZcacsSeY7CrrDLdpth1jYA: /ipfs/QmPr4ozRykRZKtfDKNqwnqZomuqFuoYzH2TPnL1pPfF8zw

elaps = Time.now - start_time

puts "Elapsed time: #{elaps}"
