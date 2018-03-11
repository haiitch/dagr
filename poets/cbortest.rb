
require 'pp'
require '../rb/dagr.rb'
require 'cbor'
require 'base64'
require 'benchmark'


c = IPFS::Client.new

kb = 2**10
numarray = [  ]

1.upto(64*kb) {|n| numarray.push(n) }
puts "Array of longints to store: "
#pp numarray

packed = numarray.pack('l*')
puts
puts "Packed string size: #{packed.size}"
puts

cborpacked = [packed].to_cbor

puts "Cbor encoded size: #{cborpacked.size}"
#puts cborpacked
puts

o = c.request( :method => :post, :cmd => "dag/put", 
               :obj => cborpacked , 
               :opts => { "format" => "cbor", "input-enc" => "cbor"} )

# => {"Cid"=>{"/"=>"zdpuB3KYyKfBPGHcasbW9UQWkzc6d2QswGj2kw17mtNY95b9u"}}
cid = o["Cid"]["/"]

o = IPFS::DAG.new(cid)
puts 
puts "Object CiD: #{cid}"
#pp o.content
puts "Base64-encoded size: #{o.content.first.size}"
puts 

puts "Decoded array:"
decoded = Base64.decode64(o.content.first)
a = decoded.unpack("l*")
puts "#{a.size} elements"