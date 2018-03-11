# dagr
### dagr is a ruby client for the api exposed by an IPFS daemon.

the current go-ipfs version I'm testing dagr against is go-ipfs 0.4.14-dev.
some samples on how to use it are available under the poets/ directory

the dagr client is presented as a one-file ruby module under the 
IPFS namespace, containing three classes:
```ruby
IPFS::Client     # simple api commands

IPFS::DAGObject  # handles IPFS node manipulation created as unixfs objects

IPFS::DAG        # handles IPFS node manipulation through the plain dag api commands
```

both DAGObject and DAG make use of IPFS::Client to store and retrieve 
dag nodes offering convenience methods and operators to walk dags
following the two distinct conventions of each method.

when used in isolation, IPFS::Client offers access to many other
simple api subcommands (under the api's key, name, block, etc. commands)
for example the method IPFS::Client#publish is a convenient way
to access the IPNS name/publish api call.

a number of api calls remain unimplemented, whilst presenting a 
complete api is not the primary goal of this project, I'll do my
best to complete it as needed, and I'll accept any fixes, additions,
and suggestions that follow a lean and mean philosophy as a priority
over [architectural astronautics](https://www.joelonsoftware.com/2001/04/21/dont-let-architecture-astronauts-scare-you/).


so far, no effort has been made to implement correct error handling, 
nor correct capitalisation of documentation.
It's all going to be embellished once I'm done completing parts 
of the api I need for another project of mine.

