# dagr

dagr is a ruby client for the api exposed by an IPFS daemon.
the current go-ipfs version I'm testing dagr against is go-ipfs 0.4.14-dev.

some samples on how to use it are available under the poets/ directory

the dagr client is presented as a one-file ruby module under the 
IPFS namespace, containing three classes:

IPFS::Client

IPFS::DAGObject

IPFS::DAG

no effort has been made to implement correct error handling.
It's all going to be embellished once I'm done completing parts 
of the api I need for another project of mine.

