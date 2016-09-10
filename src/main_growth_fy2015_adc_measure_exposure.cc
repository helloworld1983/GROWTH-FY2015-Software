/*
 * main_growth_fy2015_adc_measure_exposure.cc
 *
 *  Created on: Sep 27, 2015
 *      Author: yuasa
 */

#include "GROWTH_FY2015_ADC.hh"
#include "EventListFileFITS.hh"

#include "MessageServer.hh"

#ifdef USE_ROOT
#include "EventListFileROOT.hh"
#include "TH1D.h"
#include "TFile.h"
#endif
#ifdef DRAW_CANVAS
#include "TH1D.h"
#include "TFile.h"
#include "TApplication.h"
#include "TCanvas.h"
#include "TROOT.h"
TApplication* app;
#endif

static const uint32_t AddressOf_EventFIFO_DataCountRegister = 0x20000000;

//#define DRAW_CANVAS 0


class MainThread: public CxxUtilities::StoppableThread {
public:
	std::string deviceName;
	std::string configurationFile;
	double exposureInSec;

public:
	MainThread(std::string deviceName, std::string configurationFile, double exposureInSec) {
		this->deviceName = deviceName;
		this->exposureInSec = exposureInSec;
		this->configurationFile = configurationFile;
	}

private:
	const size_t GPSRegisterReadWaitInSec = 30; //30s
	uint32_t unixTimeOfLastGPSRegisterRead = 0;

private:
	void readAnsSaveGPSRegister() {
		eventListFile->fillGPSTime(adcBoard->getGPSRegisterUInt8());
		unixTimeOfLastGPSRegisterRead = CxxUtilities::Time::getUNIXTimeAsUInt32();
	}

private:
	GROWTH_FY2015_ADC* adcBoard;
	CxxUtilities::Condition c;
	size_t nEvents = 0;
#ifdef DRAW_CANVAS
	TCanvas* canvas;
	TH1D* hist;
	size_t canvasUpdateCounter;
	const size_t canvasUpdateCounterMax = 10;
#endif
#ifdef USE_ROOT
	EventListFileROOT* eventListFile;
#else
	EventListFileFITS* eventListFile;
#endif

public:
	void run() {
		using namespace std;
		adcBoard = new GROWTH_FY2015_ADC(deviceName);

		uint32_t fpgaType = adcBoard->getFPGAType();
		uint32_t fpgaVersion = adcBoard->getFPGAVersion();

#ifdef DRAW_CANVAS
		//---------------------------------------------
		// Run ROOT eventloop
		//---------------------------------------------
		canvas = new TCanvas("c", "c", 500, 500);
		canvas->Draw();
		canvas->SetLogy();
#endif

		//---------------------------------------------
		// Load configuration file
		//---------------------------------------------
		if (!CxxUtilities::File::exists(this->configurationFile)) {
			cerr << "Error: YAML configuration file " << this->configurationFile << " not found." << endl;
			::exit(-1);
		}
		adcBoard->loadConfigurationFile(configurationFile);

		cout << "//---------------------------------------------" << endl //
				<< "// Start acquisition" << endl //
				<< "//---------------------------------------------" << endl;
		uint32_t startTime_unixTime = CxxUtilities::Time::getUNIXTimeAsUInt32();
		try {
			adcBoard->startAcquisition();
			cout << "Acquisition started." << endl;
		} catch (...) {
			cerr << "Failed to start acquisition." << endl;
			::exit(-1);
		}

		//---------------------------------------------
		// Create an output file
		//---------------------------------------------
		std::string outputFileName;
#ifdef USE_ROOT
		outputFileName = CxxUtilities::Time::getCurrentTimeYYYYMMDD_HHMMSS() + ".root";
		eventListFile=new EventListFileROOT(outputFileName,adcBoard->DetectorID, this->configurationFile);
#else
		outputFileName = CxxUtilities::Time::getCurrentTimeYYYYMMDD_HHMMSS() + ".fits";
		eventListFile = new EventListFileFITS(outputFileName, adcBoard->DetectorID, this->configurationFile, //
				adcBoard->getNSamplesInEventListFile(), this->exposureInSec, //
				fpgaType, fpgaVersion);
#endif
		cout << "Output file name: " << outputFileName << endl;

		//---------------------------------------------
		// Send CPU Trigger
		//---------------------------------------------
		cout << "Sending CPU Trigger" << endl;
		adcBoard->sendCPUTrigger();

		//---------------------------------------------
		// Read raw ADC values
		//---------------------------------------------
		for (size_t i = 0; i < 4; i++) {
			cout << "Ch." << i << " ADC ";
			for (size_t o = 0; o < 5; o++) {
				cout << (uint32_t) adcBoard->getCurrentADCValue(i) << " " << endl;
			}
		}

		//---------------------------------------------
		// Read GPS Register
		//---------------------------------------------
		cout << "Reading GPS Register" << endl;
		cout << adcBoard->getGPSRegister() << endl;
		this->readAnsSaveGPSRegister();

		//---------------------------------------------
		// Read events
		//---------------------------------------------
#ifdef DRAW_CANVAS
		hist = new TH1D("h", "Histogram", 1024, 0, 1024);
		hist->GetXaxis()->SetRangeUser(480, 1024);
		hist->GetXaxis()->SetTitle("ADC Channel");
		hist->GetYaxis()->SetTitle("Counts");
		hist->Draw();
		canvas->Update();
		canvasUpdateCounter = 0;
#endif

		uint32_t elapsedTime = 0;
		size_t nReceivedEvents = 0;
		stopped = false;
		while (elapsedTime < this->exposureInSec && !stopped) {
			nReceivedEvents = readAndThenSaveEvents();
			if (nReceivedEvents == 0) {
				c.wait(50);
			}
			//get current unixtime
			uint32_t currentUnixTime = CxxUtilities::Time::getUNIXTimeAsUInt32();
			//read GPS register if necessary
			if (currentUnixTime - unixTimeOfLastGPSRegisterRead > GPSRegisterReadWaitInSec) {
				this->readAnsSaveGPSRegister();
			}
			//update elapsed time
			elapsedTime = currentUnixTime - startTime_unixTime;
		}

#ifdef DRAW_CANVAS
		cout << "Saving histogram" << endl;
		TFile* file = new TFile("histogram.root", "recreate");
		file->cd();
		hist->Write();
		file->Close();
#endif

		//stop acquisition first
		adcBoard->stopAcquisition();

		//completely read the EventFIFO
		readAndThenSaveEvents();
		cout << "Saving event list" << endl;
		eventListFile->close();

		adcBoard->closeDevice();
		cout << "Waiting child threads to be finalized..." << endl;
		c.wait(1000);
		cout << "Deleting ADCBoard instance." << endl;
		delete adcBoard;
	}

private:
	size_t readAndThenSaveEvents() {
		using namespace std;
		std::vector<GROWTH_FY2015_ADC_Type::Event*> events = adcBoard->getEvent();
		cout << "Received " << events.size() << " events" << endl;
		eventListFile->fillEvents(events);

#ifdef DRAW_CANVAS
		cout << "Filling to hitoram" << endl;
		for (auto event : events) {
			hist->Fill(event->phaMax);
		}
#endif

		size_t nReceivedEvents = events.size();
		nEvents += nReceivedEvents;
		cout << events.size() << " events (" << nEvents << ")" << endl;
		adcBoard->freeEvents(events);

#ifdef DRAW_CANVAS
		canvasUpdateCounter++;
		if (canvasUpdateCounter == canvasUpdateCounterMax) {
			cout << "Update canvas." << endl;
			canvasUpdateCounter = 0;
			hist->Draw();
			canvas->Update();
		}
#endif

		return nReceivedEvents;
	}

private:
	void debug_readStatus(int debugChannel = 3) {
		using namespace std;
		//---------------------------------------------
		// Read status
		//---------------------------------------------
		ChannelModule* channelModule = adcBoard->getChannelRegister(debugChannel);
		printf("Debugging Ch.%d\n", debugChannel);
		printf("ADC          = %d\n", channelModule->getCurrentADCValue());
		printf("Livetime     = %d\n", channelModule->getLivetime());
		cout << channelModule->getStatus() << endl;

		size_t eventFIFODataCount = adcBoard->getRMAPHandler()->getRegister(AddressOf_EventFIFO_DataCountRegister);
		printf("EventFIFO Count = %zu\n", eventFIFODataCount);
		printf("TriggerCount = %zu\n", channelModule->getTriggerCount());
		printf("ADC          = %d\n", channelModule->getCurrentADCValue());

	}
};

int main(int argc, char* argv[]) {
	using namespace std;

	// Process arguments
	if (argc < 4) {
		cerr << "Provide UART device name (e.g. /dev/tty.usb-aaa-bbb), YAML configuration file, and exposure.." << endl;
		::exit(-1);
	}
	std::string deviceName(argv[1]);
	std::string configurationFile(argv[2]);
	double exposureInSec = atoi(argv[3]);

	int dummyArgc = 0;
	char* dummyArgv[] = { (char*) "" };
#ifdef DRAW_CANVAS
	app = new TApplication("app", &dummyArgc, dummyArgv);
#endif

	// Instantiate
	MainThread* mainThread = new MainThread(deviceName, configurationFile, exposureInSec);
	MessageServer* messageServer = new MessageServer(mainThread);

#ifdef DRAW_CANVAS
	mainThread->start();
	CxxUtilities::Condition c;
	c.wait(3000);
	app->Run();
	c.wait(3000);
#else
	// Run
	mainThread->run();
	messageServer->run();
	messageServer->join();
	mainThread->join();
#endif

	// Delete
	delete mainThread;
	delete messageServer;

	return 0;
}

