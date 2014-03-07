#!/bin/sh

# Build the image

# first copy the notebooks to here

cp -r ../notebooks .

docker build -t 'alanz/IHaskell' .

# run with 
# docker run -p 2222:22 -p 8778:8778 -d 'alanz/IHaskell'
