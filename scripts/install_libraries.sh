#!/bin/bash

if [ ! -d $HOME/work/install ]; then
mkdir -p $HOME/work/install
fi

cd $HOME/work/install
if [ ! -d SpaceWireRMAPLibrary ]; then
git clone https://github.com/yuasatakayuki/SpaceWireRMAPLibrary.git
fi

if [ ! -d CxxUtilities ]; then
git clone https://github.com/yuasatakayuki/CxxUtilities.git
fi

if [ ! -d XMLUtilities ]; then
git clone https://github.com/sakuraisoki/XMLUtilities.git
fi

cd $HOME/work/install/XMLUtilities
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/work/install
make install
cd $HOME/work/install

cd $HOME/work/install/CxxUtilities
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/work/install
make install
cd $HOME/work

cd $HOME/work/install/SpaceWireRMAPLibrary
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/work/install
make install
cd $HOME/work

