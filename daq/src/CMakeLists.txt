#=============================================
# Definition of project
#=============================================
project( GROWTH_DAQ CXX)
cmake_minimum_required(VERSION 2.8)
set (CMAKE_CXX_STANDARD 11)

#=============================================
# Initial definition of cmake variables
#=============================================
set(CMAKE_INSTALL_PREFIX $ENV{HOME}/work/install CACHE PATH "install prefix")
set(CMAKE_BUILD_TYPE Release CACHE STRING "build type")

#=============================================
# Include path
#=============================================
include_directories(
  .
  picojson
)

#=============================================
# Link directories
#=============================================
link_directories(
)

#=============================================
# Executable definitions
#=============================================
#---------------------------------------------
# Executable source
#---------------------------------------------
add_executable(growth_adc_daq
  growth_adc_daq.cc

)

#---------------------------------------------
# Linked libraries
#---------------------------------------------
target_link_libraries(growth_adc_daq
  cfitsio
  yaml-cpp
  zmq
  xerces-c
  boost_system
  boost_thread-mt
)

#=============================================
# Installs
#=============================================
install_targets(/bin growth_adc_daq)

