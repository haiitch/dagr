
require "../rb/dagr.rb"
require "pp"

include IPFS

start_time = Time.now

# change the default endpoint
IPFS::Client.new("http://127.0.0.1:45001/api/v0")

dago1 = DAGObject.new
puts "DIR #{dago1.cid}"

dag1 = DAG.new( { a: 1, b: 2, c: 3 } )
puts "DAG #{dag1.cid}"

dag2 = DAG.new( { artist: "Ramones", phrase: "Hey, ho! Let's go!" } )
puts "DAG #{dag2.cid}"

dag3 = DAG.new( { country: "Australia", capital: "Canberra" } )
puts "DAG #{dag3.cid}"


dago1.add_link( "abc",     dag1.cid )
dago1.add_link( "ramones", dag2.cid )
dago1.add_link( "city",    dag3.cid )


dago2 = DAGObject.new
	dago2.add_link( "bands", dago1.cid ) 

dag2 = DAG.new( { artist: "Ramones", phrase: "Hey ho let's go", touring: { "/" => dag3.cid } } )

dago1.rm_link("ramones")
dago1.add_link("ramones", dag2.cid)

dago2.rm_link("bands")
dago2.add_link("bands", dago1.cid)

puts "Web url: #{dago2.url}"

#pp dago2.>>(:bands)
puts "touring: " 


touring = dago2.>>(:bands).>>(:ramones).>>(:touring)


puts " artist:" + dag2.node.artist
puts "country:" + touring.node.country
puts "   city:" + touring.node.capital

puts dag2.node.artist + " are opening their " + touring.node.country + " tour in " + touring.node.capital + " tonight."


puts dago2.>>(:bands).>>(:city)[:capital]

puts ((dago2>>:bands)>>:city)[:capital]  # the same

puts dago2.cid


elaps = Time.now - start_time

puts "Elapsed time: #{elaps}"