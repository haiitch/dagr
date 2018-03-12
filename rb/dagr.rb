require 'json'
require 'pp'
require 'base64'
require 'restclient'


module IPFS
	DEFAULT_API_ENDPOINT = "http://127.0.0.1:5001/api/v0"

	class Client
		def initialize(api = nil, parent: nil)
			if api==nil then 
				begin
					@endpoint=@@api_endpoint
				rescue
					@@api_endpoint=IPFS::DEFAULT_API_ENDPOINT
					@endpoint=IPFS::DEFAULT_API_ENDPOINT	
				end
			else
				@endpoint=api 
				@@api_endpoint=api 
			end 

			begin 
				@dagcache=@@dagnodestore
			rescue 
				@@dagnodestore={}
				@dagcache=@@dagnodestore
			end
		end

		def endpoint
			@endpoint
		end

		def cache
			@dagcache
		end

		def endpoint=(endpoint)
			@endpoint 
		end

        def request( method: :get, 
        			 cmd:    "id", 
        			 args:   []  , 
        			 obj:    nil ,
        			 opts:   {},
        			 json:   true
        			)
        	klass=obj.class.to_s
        	if ["Hash", "Array"].include?(klass) then
        		method = :post
        		payload = {
        			multipart: true,
        			file: obj.to_json
        		}
        	elsif klass=="File"	   
        			method = :post      			 
        			payload = {
        				multipart: true,
        				file: obj.read
        			}
        	
        	elsif klass=="String"
        			method = :post
        			payload = {
        				multipart: true,
        				file: obj 
        			}
        	else
        		payload = nil 
        	end

        	url = self.endpoint()+"/"+cmd

        	urlargs=""
        	urlopts=""
        	allargs=[]

        	if opts.size>0 then
        		urlopts=opts.map{|k,v| "#{k}=#{v}" }.join("&")
        		allargs.push(urlopts) if !urlopts.empty?
        	end

        	if args.size>1 then
        		urlargs=args.map{|elem| "arg="+elem}.join("&")  # arg=a&arg=b&arg=c
        		allargs.push(urlargs) if !"#{urlargs}".empty?
        		urlargs = allargs.join("&")
        		url=url+"?"+urlargs if !urlargs.strip.empty?
        	elsif args.size==1
        		urlargs = args.first.to_s
        		url=[url+"/"+urlargs, urlopts].join("?")
        	elsif args.size==0
        		url=[url+"/", urlopts].join("?") if !urlopts.empty?
        	end

			rest = RestClient::Request.new(
				 :method => method,
				 :url => url,
				 :payload => payload
			)

			begin
				result = rest.execute
			rescue
				throw "Error: REST client request failed"
				# TO-DO: fix this. I have no idea how to get the
				# error message in the response body using restclient
			end
			if json then 
				begin
					robj = JSON.parse(result.body)
				rescue
					throw "Error: parsing JSON"
				end
			else
				return result.body
			end 

			return robj
		end

		#   TO-DO: Implementing this, work in progress
		#
		#   Walk returns the object (DAGObject, DAG, or Block) pointed 
		#   by a path reference, resolving as appropriate when possible
		#
		#   / => Qm...   Cid0 Contains normal DAG Object
		#   / => zdp..   Cid1 Contains plain DAG
		#
		#   @ => Qm...   Cid0 IPNS reference to DAG Object
		#   @ => zdp..   Cid1 IPNS reference to plain dag
		#
		#   # => Qm...   Cid0 Contains a block with raw bytes
		#   $ => Qm...   Cid0 Contains a block with bytes of CBOR-encoded object
		#
		def walk(path)
		end


		# the url method is not part of the standard ipfs api, but it's handy
		# to get a web address pointing to the ipfs ui for the host
		# the client is connected to.
		# An ipns-style uri will be built if the ipns parameter is specified,
		# but no attempt is made to verify that the given cid corresponds to
		# a valid ipns address. A valid ipns address could be verifiable 
		# matching it against locally available keys, but we may well want
		# to link objects to things that exist outside our local repo. 
		# In that case, it's impossible to have prior knowledge on  whether 
		# a cid corresponds to an ipns key existing somewhere else in the universe.
		def url(cid=nil, ipns: false)
			throw "Error: must specify a valid cid to build address" if !cid 
			prot = ipns ? "ipns" : "ipfs"
			addr = config.Addresses["Gateway"].split("/")
			return "http://#{addr[2]}:#{addr[4]}/#{prot}/#{cid}"
		end

		######### IPFS BASIC COMMANDS ##########
		# a few other commands are missing like cat
		# but it doesn't seem to make much sense to implement the old
		# commands, parsing the data field by hand. 
		# (it contains protobuf format markers)
		# new applications should probably use DAG objects and 
		# the ipfs dag commands
		def add(obj)
        		begin
				dagobj = request( cmd: "add", method: :post, obj: obj)
			rescue
				throw "Error: couldn't add #{obj}"
			end 
			DAGObject.new(dagobj["Hash"])
		end

		def ls(addr)			
        		begin 				
				list = request( cmd: "ls", args: [addr])
			rescue
				throw "Error: couldn't execute ls #{addr}"
			end 
		end 

		######### NAME ##########
		# no attempt is made to check if key is valid
		# TO-DO: check whether default options are sound
		def publish(key, obj)
				klass = obj.class.to_s 
				path = ""
				if ["String", "Symbol"].include?(klass) then
						path=request( cmd: "name/publish", args: [obj], opts: {:key=>key})
				elsif obj.respond_to?(:cid) 
						path=request( cmd: "name/publish", args: [obj.cid], opts: {:key=>key})
				elsif ["Hash", "Array"].include?(klass)
						path=request( cmd: "name/publish", args: [DAG.new(obj).cid], opts: {:key=>key} )
				else
					throw "Error: obj must be a cid, a dag object, or hash/array data to make a dag object"
				end			
				path["Name"]
		end			

		def resolve(ipnspath, recursive: false, nocache: false)
				opts = { recursive: recursive, nocache: nocache}

				begin
					path = request( cmd: "name/resolve", args: [ipnspath], opts: opts )
					return path["Path"].split("/").last
				rescue 
					throw "Error: Couldn't resolve #{ipnspath}"
				end 
		end			


		# command is a helper that may not be too helpful if all parameters are specified
		# (that would make it practically the same as calling self.request anyway)
		def command(cmd, args: [], opts: {})
				request( cmd: cmd, args: args, opts: opts )
		end 


		######### BLOCK ##########
		def block_put(data)
			klass= data.class.to_s 
			if ["Array", "Hash"].include?(klass) then 
				data = data.to_json 
			end  
			d = request(:cmd => "block/put", :obj => data )	
			d["Key"] if d["Key"]!=nil 
		end
		alias_method :blockput, :block_put 
		alias_method :put, :block_put

		def block_get(key)
			d = request(:cmd => "block/get", :args => [key], json: false )
		end
		alias_method :blockget, :block_get 
		alias_method :get, :block_get

		# handle with care, use in a thread or goroutine only
		# block/rm takes too long to complete, synchronous calls may
		# block your application for too long.
		# if you timeout or abort, you may not be able to learn 
		# whether the operation was successful
		def block_rm(key)
			d = request(:cmd => "block/rm", :args => [key], json: false )
		end
		alias_method :blockrm, :block_rm 

		def block_stat(key)
			OpenStruct.new(request(:cmd => "block/stat", :args => [key] ))				
		end
		alias_method :blockstat, :block_stat 


		######### ID ##########
		def host_id	
				OpenStruct.new(command("id"))
		end 
		alias_method :id, :host_id 
		alias_method :host, :host_id 


		######### CONFIG ##########
		# TO-DO: Check whether any other config subcommands are
		# good for anything in a client application's context
		def config
				OpenStruct.new(command("config/show"))
		end


		######### SWARM ##########		
		# TO-DO: implement missing methods
		def swarm_peers
				command("swarm/peers")["Peers"]
		end
		alias_method :peers, :swarm_peers
		alias_method :swarmpeers, :swarm_peers


		######### KEY ##########
		# TO-DO: complete this, experiment to find out whether we need
		# a separate class for key handling, possibly in tandem with
		# ipfs name commands where applicable
		def key_list
				command("key/list", opts: {l: true} )["Keys"]
		end			


		######### DIAG ##########
		def diag_cmds
				command("diag/cmds")
		end			

		def diag_sys
        		OpenStruct.new(command("diag/sys"))
		end	


		########## STATS #########
		def stats_bitswap
				OpenStruct.new(command("stats/bw"))
		end

		def stats_bw 
				OpenStruct.new(command("stats/bitswap"))
		end 

		def stats_repo 
				OpenStruct.new(command("stats/repo"))
		end 


		######### REPO ##########
		def repo_fsck
				command("repo/fsck")
		end

		def repo_gc
				command("repo/gc") 	
		end

		def repo_stat
				OpenStruct.new(command("repo/stat"))
		end

		def repo_verify
				command("repo/verify")
		end

		def repo_version
				command("repo/version")["Version"]
		end 


		######### PIN ##########
		# all these pin things seem incredibly slow at this time
		# handle with care, and make sure to use these calls only 
		# asynchronously in separate threads or goroutines, else
		# they will block your application for too long waiting
		# for a response from the api endpoint. 
		def pin_add(path)
			d = request(:cmd => "pin/add", :args => [path] )
		end
		alias_method :pinadd, :pin_add

		def pin_ls(path)
			d = request(:cmd => "pin/ls", :args => [path] )
		end
		alias_method :pinls, :pin_ls

		def pin_rm(path)
			d = request(:cmd => "pin/rm", :args => [path] )
		end
		alias_method :pinrm, :pin_rm

		def pin_update(from_path, to_path)
			puts "pin_update unimplemented for now. TO-DO: look up how to use this."
		end
		alias_method :pinupdate, :pin_update

		def pin_verify(verbose: false)
			d = request(:cmd => "pin/verify", :opts => { verbose => false } )
		end
		alias_method :pinverify, :pin_verify

	end


	class DAGObject
		attr_reader :cid, :links, :data

        def initialize(obj=nil)
    		self.initclient()
    		klass=self.class.to_s 
    		if self.client.cache[klass]==nil then
    			self.client.cache[klass]={} 
    		end 

			klass = obj.class.to_s 

            if ["Symbol", "String"].include?(klass) then
                    loadnode(obj)
            elsif klass=="NilClass"
                begin
	       			obj = @client.request(cmd: "object/new/unixfs-dir", args: [])
	       			id = obj["Hash"]
                rescue
                    throw "Error creating empty dag object unixfs-dir"
                end
                loadnode(id)
			elsif ["Hash", "Array"].include?(klass) 
	       			obj = @client.request(cmd: "object/new/unixfs-dir", args: [])
	       			id = obj["Hash"]
			end
        end

		def initclient
			begin 
				@client=@@client_instance.clone
			rescue
				@@client_instance=IPFS::Client.new
				@client = @@client_instance.clone
			end
		end

		def client
			@client 
		end

		def url
			@client.url(@cid)
		end 

		def get( id )
			id = id.to_s.strip
			c=self.client()
			klass=self.class.to_s 

			if c.cache[klass][id]!=nil then
				obj=c.cache[klass][id]
				# puts "CACHE HIT #{self.class.to_s}"
			else
				begin
					obj = c.request(:cmd=>"object/get", :args=> [id])
					c.cache[klass][id]=obj 
				rescue
					throw "Error getting dag object #{id}"
				end
			end

			@cid = id
			@content = obj 		

			return obj 
		end

		def loadnode(id)
				id=id.to_s.strip
				obj = get(id)
				@links = obj["Links"]
				@data  = obj["Data"]
				#@links==nil ? nil : id.to_s
				return @cid
		end

		def ===(obj)
			if obj.respond_to?(:cid) then 
				self.cid == obj.cid 
			else
				false
			end
		end

		def add_link( linkname,  linktarget)  # cid or object
			if linktarget.respond_to?(:cid) then  # can pass cid as string, DAGObject, or DAG
				linktarget=linktarget.cid 
			end
		    id = nil
		    c=self.client()
			obj = c.request(cmd: "object/patch/add-link", args: [@cid, linkname, linktarget])
	
			begin
				obj = c.request(cmd: "object/patch/add-link", args: [@cid, linkname, linktarget])
				id = obj["Hash"]
			rescue
				throw "Error patching object #{@cid}"
			end

			@cid = obj
			loadnode(id) if @cid 
		end

		def rm_link( linkname )
			id = nil
			c=self.client()

			begin
				obj = c.request(:cmd=>"object/patch/rm-link", :args=> [@cid,linkname])
				id = obj["Hash"]
			rescue
				throw "Error removing object #{@cid}"
			end

			@cid = id
			loadnode(id) if @cid 
		end

		def follow(index)
			cid = self.links()[index]["Hash"]
			return DAGObject.new(cid)
		end
		alias_method :>, :follow 

		def follow_name(linkname)
			linkname = linkname.to_s
			linklist = self.links()
			linklist=[] if linklist==nil

			linklist.each {|entry|
				if entry["Name"]==linkname then
					cid=entry["Hash"]
					if cid[0..1]=="Qm" && cid.size==46 then 
						return DAGObject.new(cid)
					else
						return DAG.new(cid)
					end
				end
			}
			return nil
		end
		alias_method :>>, :follow_name	
	end

	class DAG
		attr_reader :cid, :content

		def initialize(obj)
			initclient()
			klass=self.class.to_s

			if self.client.cache[klass]==nil then 
				self.client.cache[klass]={}
			end

			if ["Symbol", "String"].include?(obj.class.to_s) then
				self.get(obj)
			else
				id = self.put(obj)		
			end
		end			

		def initclient
			begin 
				@client=@@client_instance.clone
			rescue
				@@client_instance=IPFS::Client.new
				@client = @@client_instance.clone
			end
		end

		def client
			@client 
		end

		def url
			@client.url(@cid)
		end 

		def get( id )
			id = id.to_s.strip
			c=self.client()
			klass=self.class.to_s 

			if c.cache[klass][id]!=nil then
				obj=c.cache[klass][id]
				# puts "CACHE HIT #{self.class.to_s}"
			else			
				begin
					obj = c.request(:cmd=>"dag/get", :args=> [id])
					c.cache[klass][id]=obj
				rescue
					throw "Error getting dag object #{id}"
				end
			end

			@cid = id.to_s.strip
			@content = obj 		
			return obj 
		end

		def put( obj )
			id=nil
			opts = { :format=> :cbor, :"input-enc" => :json }
			c=self.client()

			begin
				robj = c.request(:cmd=>"dag/put", :args=> [], :obj=> obj, :opts => opts)
			rescue
				throw "Error putting dag object #{obj}"
			end

			@cid = robj["Cid"]["/"]
			@content = obj 		
			return @cid 
		end 


		def [](key)
			key = key.to_s 
			return @content[key]
		end 

		def links
			return self["links"] 
		end

		def ===(obj)
			if obj.respond_to?(:cid) then 
				self.cid == obj.cid 
			else
				false
			end
		end

		def follow(index)
			cid = self.links()[index]["Cid"]["/"]
			return DAG.new(cid)
		end
		alias_method :>, :follow 

		def follow_name(linkname)
			linkmame = linkname.to_s 
			if self.links() then 
				linkname = linkname.to_s
				linklist = self.links()
				linklist.each {|entry|
					if entry["Name"]==linkname then
						cid=entry["Cid"]["/"]
						return DAG.new(cid)
					end
				}
				return nil
			else
				# puts "following #{linkname}"
				cid=self.node[linkname.to_s]["/"]
				return DAG.new(cid)
			end
		end
		alias_method :>>, :follow_name

		def node(key=nil)
			if key==nil then 
				if self["Node"] then 
					return OpenStruct.new(self["Node"])
				else
					return OpenStruct.new(@content)
				end
			end
			return OpenStruct.new(self[key])
		end
		alias_method :/, :node 


		def data
			return Base64.decode64( self["data"] )
		end

		def save(filename, overwrite=false)
		if overwrite || !File.exists?(filename) then 
			begin 
				f=File.open(filename,"w")
				f.write( self.data )
				f.close
			rescue
				throw "Error: File #{filename} can't be saved"
			end
		end
		end

		def to_s
			return self.cid 
		end
	end
end

# The following should be made optional as they tamper with
# standard Ruby classes, but they're handy enough that many
# people may find them useful.

# Path walking over Hash
class Hash
		def node
			OpenStruct.new(self)
		end

		def walk(key)
			node.send key 
		end  
		alias_method :/, :walk 

		def follow(key="Cid")
			d = self[key.to_s]
			if d then
				if d["/"] then
					return DAG.new(d["/"])
				end
			end
			return nil
		end
		alias_method :>, :follow
		alias_method :>>, :follow
end

# Path walking over OpenStruct
class OpenStruct
		alias_method :/, :send

		def follow(key)
			key = key.to_s
			val = self[key]
			dag = val["/"]? DAG.new(val["/"]) : nil 
		end
		alias_method :>, :follow 
		alias_method :>>, :follow 
end

# Path walking over Array
class Array
		def walk(index)
			self.send(:[], index)
		end
		alias_method :/, :walk 
end

# Path walking examples into hashes, arrays, and openstructs
#
# irb(main):001:0> list = IPFS::Client.new.ls(:QmUBNHKQTk6Z59whVNoCkpyzf1LW1xtGDTQHBKSQ62MJDw)
# => {"Objects"=>[{"Hash"=>"QmUBNHKQTk6Z59whVNoCkpyzf1LW1xtGDTQHBKSQ62MJDw", "Links"=>[{"Name"=>"adjacency", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}, {"Name"=>"edges", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}, {"Name"=>"graph", "Hash"=>"zdpuAwQpnfPxpTKBbLYGVzBQgAULvM8wTetikLNigKboomQEN", "Size"=>79, "Type"=>-1}, {"Name"=>"nodes", "Hash"=>"QmT11B7QhU1mTqWj5ysuyKRVC6srvqS6pcC1aVvMvcNnDr", "Size"=>3618, "Type"=>1}, {"Name"=>"view", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}]}]}
#
# irb(main):002:0> list/:Objects/0
# => {"Hash"=>"QmUBNHKQTk6Z59whVNoCkpyzf1LW1xtGDTQHBKSQ62MJDw", "Links"=>[{"Name"=>"adjacency", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}, {"Name"=>"edges", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}, {"Name"=>"graph", "Hash"=>"zdpuAwQpnfPxpTKBbLYGVzBQgAULvM8wTetikLNigKboomQEN", "Size"=>79, "Type"=>-1}, {"Name"=>"nodes", "Hash"=>"QmT11B7QhU1mTqWj5ysuyKRVC6srvqS6pcC1aVvMvcNnDr", "Size"=>3618, "Type"=>1}, {"Name"=>"view", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}]}
#
# irb(main):003:0> list/:Objects/0/:Links/0
# => {"Name"=>"adjacency", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}
#
# irb(main):004:0> list/:Objects/0/:Links/1
# => {"Name"=>"edges", "Hash"=>"QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn", "Size"=>4, "Type"=>1}
#
# irb(main):025:0> list/:Objects/0/:Links/0/:Name
# => "adjacency"
#
# irb(main):014:0> list/:Objects/0/:Links/1/:Name
# => "edges"
#
# irb(main):020:0> list/:Objects/0/:Links/2/:Name
# => "graph"
#
# irb(main):021:0> list/:Objects/0/:Links/3/:Name
# => "nodes"
#
# irb(main):022:0> list/:Objects/0/:Links/4/:Name
# => "view"


class Fixnum 
		def hex(digits=8)
			("%#{digits}s".%(self.to_s(16))).gsub(" ","0")
		end
end
