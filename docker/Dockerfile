# set up an IHaskell instance
# 
# build with 
#  docker build -t 'alanz/IHaskell' .

FROM alanz/haskell-platform-2013.2-deb64

MAINTAINER alan.zimm@gmail.com

ENV DEBIAN_FRONTEND noninteractive

#-----------------------------------------------------------------------
# Install emacs and ssh server
RUN echo "deb http://cdn.debian.net/debian/ testing main non-free contrib" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y dist-upgrade

RUN apt-get -y install python-dev
RUN apt-get -y install automake
RUN apt-get -y install libtool
RUN apt-get -y install g++
RUN apt-get -y install libtinfo-dev libncurses5-dev
RUN apt-get -y install sudo

RUN wget https://github.com/zeromq/zeromq4-x/archive/v4.0.3.tar.gz
RUN tar xvfz v4.0.3.tar.gz

RUN cd zeromq4-x-4.0.3 && ./autogen.sh
RUN cd zeromq4-x-4.0.3 && ./configure
RUN cd zeromq4-x-4.0.3 && make
RUN cd zeromq4-x-4.0.3 && make install


#-----------------------------------------------------------------------

#ADD . /src

#RUN /src/setup.sh

#DOCKER_PASSWORD=password
#echo User: docker Password: $DOCKER_PASSWORD
#DOCKER_ENCRYPYTED_PASSWORD=`perl -e 'print crypt('"$DOCKER_PASSWORD"', "aa"),"\n"'`
#useradd -m -d /home/docker -p $DOCKER_ENCRYPYTED_PASSWORD docker
RUN useradd -m -d /home/docker  docker
RUN sed -Ei 's/adm:x:4:/docker:x:4:docker/' /etc/group
RUN adduser docker sudo

# Set the default shell as bash for docker user.
RUN chsh -s /bin/bash docker

#-----------------------------------------------------------------------

RUN sudo -u docker echo "export PATH=~/.cabal/bin:$PATH" >> ~/.bashrc

RUN sudo -u docker cabal update

RUN sudo -u docker cabal install cabal-install
RUN sudo -u docker cabal install happy cpphs

# RUN sudo -u docker cabal install zeromq4-haskell

RUN sudo -u docker cabal install ipython-kernel
RUN sudo -u docker cabal install ghci-lib
RUN sudo -u docker cabal install haskell-src-exts
RUN sudo -u docker cabal install ghc-parser
RUN sudo -u docker cabal install tar
RUN sudo -u docker cabal install hlint
RUN sudo -u docker cabal install haskell-src-meta
RUN sudo -u docker cabal install haskeline
RUN sudo -u docker cabal install hspec
RUN sudo -u docker cabal install shelly
RUN sudo -u docker cabal install classy-prelude-0.7.0

# RUN echo "export PATH=~/.cabal/bin:$PATH" >> /etc/profile
RUN sudo -i -u docker bash -c 'export PATH=~/.cabal/bin:$PATH && cabal install ihaskell'

# RUN sudo -u docker cabal install ihaskell
RUN sudo -u docker cabal install ihaskell-aeson
RUN sudo -u docker cabal install ihaskell-blaze
RUN sudo -u docker cabal install gtk2hs-buildtools
RUN apt-get -y install libgtk2.0-dev libgtk-3-dev
RUN sudo -i -u docker bash -c 'export PATH=~/.cabal/bin:$PATH && cabal install cairo'
RUN sudo -i -u docker bash -c 'export PATH=~/.cabal/bin:$PATH && cabal install ihaskell-charts'
RUN sudo -u docker cabal install ihaskell-diagrams
RUN sudo -u docker cabal install ihaskell-display
RUN apt-get -y install libmagic-dev
RUN sudo -u docker cabal install ihaskell-magic

