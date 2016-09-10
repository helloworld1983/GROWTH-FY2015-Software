#ifndef SRC_MAINTHREAD_HH_
#define SRC_MAINTHREAD_HH_

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

#include "GROWTH_FY2015_ADC.hh"
#include "EventListFileFITS.hh"

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
		// Log start time
		//---------------------------------------------
		startUnixTime = CxxUtilities::Time::getUNIXTimeAsUInt32();

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

public:
	const size_t getNEvents() const {
		return nEvents;
	}

public:
	const size_t getElapsedTime() const {
		uint32_t currentUnixTime = CxxUtilities::Time::getUNIXTimeAsUInt32();
		return currentUnixTime - startUnixTime;
	}

public:
	const std::string getOutputFileName() const {
		return outputFileName;
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
		size_t eventFIFODataCount = adcBoard->getRMAPHandler()->getRegister(//
				ConsumerManagerEventFIFO::AddressOf_EventFIFO_DataCount_Register);
		printf("EventFIFO Count = %zu\n", eventFIFODataCount);
		printf("TriggerCount = %zu\n", channelModule->getTriggerCount());
		printf("ADC          = %d\n", channelModule->getCurrentADCValue());
	}

private:
	uint32_t startUnixTime;
	std::string outputFileName;
};

#endif /* SRC_MAINTHREAD_HH_ */
