
require 'pp'
require '../rb/dagr.rb'
require 'cbor'
require 'base64'

c = IPFS::Client.new

kb = 2**10
numarray = []

count = kb*64

1.upto(count) {|n| numarray.push((rand*count).floor) }
puts "Array of longints to store: "
pp numarray.size

packed = numarray.pack('l*')
puts
puts "Packed string size: #{packed.size}"
puts
start_time = Time.now
cborpacked = numarray.to_cbor

puts "Cbor encoded size: #{cborpacked.size}"
#puts cborpacked
puts
puts "Packed string ratio: #{packed.size*1.0/count}"
puts "  CBOR packed ratio: #{cborpacked.size*1.0/count}"

cid = c.block_put(cborpacked)
puts "Block CiD: #{cid}"
puts

puts "Elapsed: #{Time.now-start_time}"

blockback = c.block_get(cid)
puts "Retrieved:"
blockback = CBOR.unpack(blockback)
pp blockback.size  
#pp blockback.unpack("l*")

