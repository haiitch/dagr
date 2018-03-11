#!/bin/bash

# ipfs daemon configured with different ports so that it can coexist
# in the same machine with another daemon running on standard ports

# mainly meant for offline use working during travel, and for testing
# ipns handling because local name publishing is way faster than
# performing the same operations on the public internets.

# start with -D parameter to enable a verbose debug log  
# ./ipfstart.sh -D 

OPT=$1
DELAY=5

REPO1="$HOME/ipfs/testrepo"
REPO2="$HOME/.ipfs"


IPFSD="ipfs daemon $OPT --config=$REPO1 --enable-pubsub-experiment --enable-namesys-pubsub"

IPFSN="ipfs daemon $OPT --config=$REPO2 --enable-pubsub-experiment --enable-namesys-pubsub"

###############################################################################

coproc $IPFSD

# wait for a bit
sleep $DELAY 

# ipfsn = normal ipfs daemon with configuration in ~/.ipfs
coproc $IPFSN 

###############################################################################

# give enough time until daemons are ready, then connect them
echo "Starting daemons"

sleep $DELAY
echo "Connecting swarm locally"

# the id of your REPO1 local peer will be different here, change accordingly
ipfs swarm connect /ip4/127.0.0.1/tcp/44001/ipfs/QmW6T9pUeWWGQfhuPuw8pFxfTKoc3Jm2nvNy5e5A631thw

sleep $DELAY
echo "########################################################################"
echo "Local peer data"
ipfs  --config=$REPO2 id

echo "........................................................................"
echo "Testrepo peer data"
ipfs  --config=$REPO1 id

sleep $DELAY
echo "########################################################################"
echo "Connected peers"
ipfs --config=$REPO2 swarm peers

