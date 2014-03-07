#!/bin/bash

sudo /etc/init.d/ssh start

sudo -i -u docker bash -c '(cd /home/docker && export PATH=/home/docker/.cabal/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games && IHaskell notebook)'

