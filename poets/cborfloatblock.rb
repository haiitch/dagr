
require 'pp'
require '../rb/dagr.rb'
require 'cbor'
require 'base64'


c = IPFS::Client.new

kb = 2**10
numarray = [  ]

1.upto(0xffff) {|n| numarray.push(Math.sin(n)) }
puts "Array of FLOATS to store: "
pp numarray.size

packed = numarray.pack('f*')
puts
puts "Packed string size: #{packed.size}"
puts
start_time = Time.now
cborpacked = numarray.to_cbor

puts "Elapsed: #{Time.now-start_time}"

puts "Cbor encoded size: #{cborpacked.size}"
#puts cborpacked
puts


cid = c.block_put(cborpacked)
puts "Block CiD: #{cid}"
puts

blockback = c.block_get(cid)
puts "Retrieved:"
blockback = CBOR.unpack(blockback)
pp blockback.size  
#pp blockback.unpack("l*")
