/*
 * test_growth_fy2015_adc_cpuTrigger.cc
 *
 *  Created on: Jun 10, 2015
 *      Author: yuasa
 */

#include "GROWTH_FY2015_ADC.hh"
#include "TH1D.h"
#include "TFile.h"

static const uint32_t AddressOf_EventFIFO_DataCountRegister = 0x20000000;

int main(int argc, char* argv[]) {
	using namespace std;
	if (argc < 2) {
		cerr << "Provide UART device name (e.g. /dev/tty.usb-aaa-bbb)" << endl;
		exit(-1);
	}
	std::string deviceName(argv[1]);
	auto adcBoard = new GROWTH_FY2015_ADC(deviceName);
	const size_t nChannels = 4;
	const size_t NumberOfSamples = 1000;
	const size_t NumberOfSamplesEventPacket = 2;
	const size_t PreTriggerSamples = 4;
	const size_t TriggerThresholds[1][4] = { { 900, 540, 900, 900 } };

	std::vector<size_t> enabledChannels = { 0, 1, 2, 3 };
	uint16_t ChannelEnableMask = 0x02; // enable all 4 channels

	//---------------------------------------------
	// Program the digitizer
	//---------------------------------------------
	try {
		//record legnth
		adcBoard->setNumberOfSamples(NumberOfSamples);
		adcBoard->setNumberOfSamplesInEventPacket(NumberOfSamplesEventPacket);

		for (auto ch : enabledChannels) {

			//pre-trigger (delay)
			adcBoard->setDepthOfDelay(ch, PreTriggerSamples);

			//trigger mode
			adcBoard->setTriggerMode(ch, SpaceFibreADC::TriggerMode::StartThreshold_NSamples_CloseThreshold);

			//threshold
			adcBoard->setStartingThreshold(ch, TriggerThresholds[0][ch]);
			adcBoard->setClosingThreshold(ch, TriggerThresholds[0][ch]);

			//adc clock 50MHz
			adcBoard->setAdcClock(SpaceFibreADC::ADCClockFrequency::ADCClock50MHz);

			//turn on ADC
			adcBoard->turnOnADCPower(ch);

		}
		cout << "Device configurtion done." << endl;
	} catch (...) {
		cerr << "Device configuration failed." << endl;
		exit(-1);
	}

	//---------------------------------------------
	// Start acquisition
	//---------------------------------------------
	std::vector<bool> startStopRegister(nChannels);
	uint16_t mask = 0x0001;
	for (size_t i = 0; i < nChannels; i++) {
		if ((ChannelEnableMask & mask) == 0) {
			startStopRegister[i] = false;
		} else {
			startStopRegister[i] = true;
		}
		mask = mask << 1;
	}
	try {
		adcBoard->startAcquisition(startStopRegister);
		cout << "Acquisition started." << endl;
	} catch (...) {
		cerr << "Failed to start acquisition." << endl;
		exit(-1);
	}

	//---------------------------------------------
	// Send CPU Trigger
	//---------------------------------------------
	for (auto ch : enabledChannels) {
		cout << "Sending CPU Trigger to Channel " << ch << endl;
		adcBoard->sendCPUTrigger(ch);
	}

	//---------------------------------------------
	// Read status
	//---------------------------------------------
	ChannelModule* channelModule = adcBoard->getChannelRegister(1);
	printf("Livetime Ch.1 = %d\n", channelModule->getLivetime());
	printf("ADC Ch.1 = %d\n", channelModule->getCurrentADCValue());
	cout << channelModule->getStatus() << endl;

	size_t eventFIFODataCount = adcBoard->getRMAPHandler()->getRegister(AddressOf_EventFIFO_DataCountRegister);
	printf("EventFIFO data count = %d\n", eventFIFODataCount);
	printf("Trigger count = %d\n", channelModule->getTriggerCount());
	printf("ADC Ch.1 = %d\n", channelModule->getCurrentADCValue());

	//---------------------------------------------
	// Read events
	//---------------------------------------------
	size_t nEvents = 0;
	size_t nEventsMax = 10000;
	TH1D* hist=new TH1D("h","h",512,0,1024);
	CxxUtilities::Condition c;
	while (nEvents < nEventsMax) {
		std::vector<SpaceFibreADC::Event*> events = adcBoard->getEvent();
		cout << "Received " << events.size() << " events" << endl;
		for (auto event : events) {
			/*
			 cout << (uint32_t) event->ch << endl;
			 for (size_t i = 0; i < event->nSamples; i++) {
			 cout << dec << (uint32_t) event->waveform[i] << " ";
			 }
			 cout << dec << endl;
			 */
			hist->Fill(event->phaMax);
		}
		nEvents += events.size();
		cout << events.size() << " events (" << nEvents << ")" << endl;
		adcBoard->freeEvents(events);
		c.wait(100);
	}

	cout << "Saving histogram" << endl;
	TFile* file=new TFile("hist.root","recreate");
	hist->Write();
	file->Close();

	adcBoard->stopAcquisition();
	adcBoard->closeDevice();
	delete adcBoard;
}
