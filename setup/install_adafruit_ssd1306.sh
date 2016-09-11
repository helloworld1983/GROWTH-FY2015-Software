#!/usr/bin/env bash

sudo apt-get install -y build-essential python-dev python-pip
sudo pip install RPi.GPIO

mkdir -p $HOME/work/install
pushd $HOME/work/install
git clone https://github.com/adafruit/Adafruit_Python_SSD1306
pushd Adafruit_Python_SSD1306
sudo python setup.py install

#check build
gpio -v

popd
popd
