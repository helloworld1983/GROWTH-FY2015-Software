# Data Acquisition Software for GROWTH FY2015 Detectors

This is a repository of data acquisition (DAQ) software for Gamma-ray/Electron detectors of the GROWTH FY2015 experiment.

## Build & Install on Mac

### External software/libraries
If Homebrew is not installed, execute:
```
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install caskroom/cask/brew-cask
```

Install dependent software/libraries unsing Homebrew.

```
# Homebrew
brew install cmake xerces-c
brew tap yuasatakayuki/hxisgd
brew install spacewirermaplibrary
brew install rubyfits
brew install rubyroot
brew install hongoscripts
brew install zeromq

# Ruby
gem install ffi-rzmq
```

### Build

```
cd src
make -f Makefile.mac prepare_external_libs
make -f Makefile.mac -j4
```

## Install on Raspberry Pi

```
# apt-get
sudo apt-get update
sudo apt-get install -y git dpkg-dev make g++ gcc binutils 
sudo apt-get install -y libx11-dev libxpm-dev libxft-dev libxext-dev python-dev
sudo apt-get install -y ruby ruby-dev wget curl curl-dev zsh
sudo apt-get install -y git cmake swig
sudo apt-get install -y gcc-4.8 g++-4.8 libboost1.50-all libxerces-c-dev
sudo apt-get install -y ruby-dev
sudo apt-get install -y libzmq3-dev

# Ruby
sudo gem install ffi-rzmq
```

### Build

```
cd scripts
bash install_libraries.sh
cd ../

cd src
make -f Makefile.pi prepare_external_libs
make -f Makefile.pi -j4
```
