all: \
	test_serial \
	test_serial_ssdtp \
	test_serial_receive \
	test_rmap_to_fpga \
	test_growth_fy2015_adc_cpuTrigger \
	test_rmaphandler 
#	test_readADC \
#	test_setDAC \

ROOT_LIBS = $(shell root-config --glibs)
ROOT_CFLAGS = $(shell root-config --cflags)

test_readADC: test_readADC.cc
	$(CXX) -std=c++11 -stdlib=libc++ $^ -lwiringPi -I../include -I../include/wiringPi

test_setDAC: test_setDAC.cc
	$(CXX) -std=c++11 -stdlib=libc++ $^ -lwiringPi -I../include -I../include/wiringPi
	
test_serial: test_serial.cc
	$(CXX) -std=c++11 -stdlib=libc++ $^ -I../include -lboost_system -lboost_thread-mt -o $@
	
test_serial_ssdtp: test_serial_ssdtp.cc
	$(CXX) -std=c++11 -stdlib=libc++ $^ -I../include -lboost_system -lboost_thread-mt -o $@
	
test_serial_receive: test_serial_receive.cc
	$(CXX) -std=c++11 -stdlib=libc++ $^ -I../include -lboost_system -lboost_thread-mt -o $@

test_rmap_to_fpga: test_rmap_to_fpga.cc
	$(CXX) -g -std=c++11 -stdlib=libc++ $^ -I../include -lboost_system -lboost_thread-mt -o $@ -lxerces-c
	

test_growth_fy2015_adc_cpuTrigger: test_growth_fy2015_adc_cpuTrigger.cc
	$(CXX) -g -std=c++11 -stdlib=libc++ $^ -I. -I../include -lboost_system -lboost_thread-mt -o $@ -lxerces-c $(ROOT_LIBS) $(ROOT_CFLAGS)

test_rmaphandler: test_rmaphandler.cc
	$(CXX) -g -std=c++11 -stdlib=libc++ $^ -I. -I../include -lboost_system -lboost_thread-mt -o $@ -lxerces-c $(ROOT_LIBS) $(ROOT_CFLAGS)
	
