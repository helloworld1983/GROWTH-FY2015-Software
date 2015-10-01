/*
 * main_growth_fy2015_adc_measure_exposure.cc
 *
 *  Created on: Sep 27, 2015
 *      Author: yuasa
 */

#include "GROWTH_FY2015_ADC.hh"
#include "EventListFileROOT.hh"
#include "EventListFileFITS.hh"
#ifdef USE_ROOT
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

public:

public:
	void run() {
		using namespace std;
		CxxUtilities::Condition c;
		auto adcBoard = new GROWTH_FY2015_ADC(deviceName);

#ifdef DRAW_CANVAS
		//---------------------------------------------
		// Run ROOT eventloop
		//---------------------------------------------
		TCanvas* canvas = new TCanvas("c", "c", 500, 500);
		canvas->Draw();
		canvas->SetLogy();
#endif

		//---------------------------------------------
		// Load configuration file
		//---------------------------------------------
		if (!CxxUtilities::File::exists(this->configurationFile)) {
			cerr << "Error: YAML configuratin file " << this->configurationFile << " not found." << endl;
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
		EventListFileROOT* eventListFile=new EventListFileROOT(outputFileName,adcBoard->DetectorID, this->configurationFile );
#else
		outputFileName = CxxUtilities::Time::getCurrentTimeYYYYMMDD_HHMMSS() + ".fits";
		EventListFileFITS* eventListFile = new EventListFileFITS(outputFileName, adcBoard->DetectorID,
				this->configurationFile, adcBoard->getNSamplesInEventListFile());
#endif
		cout << "Output file name: " << outputFileName << endl;

		//---------------------------------------------
		// Send CPU Trigger
		//---------------------------------------------
		cout << "Sending CPU Trigger" << endl;
		adcBoard->sendCPUTrigger();

		//---------------------------------------------
		// Read GPS Register
		//---------------------------------------------
		cout << "Reading GPS Register" << endl;
		cout << adcBoard->getGPSRegister() << endl;
		eventListFile->fillGPSTime(adcBoard->getGPSRegisterUInt8());
		c.wait(1500);
		cout << adcBoard->getGPSRegister() << endl;
		eventListFile->fillGPSTime(adcBoard->getGPSRegisterUInt8());

		//---------------------------------------------
		// Read status
		//---------------------------------------------
		int debugChannel = 3;

		ChannelModule* channelModule = adcBoard->getChannelRegister(debugChannel);
		printf("Debugging Ch.%d\n", debugChannel);
		printf("ADC          = %d\n", channelModule->getCurrentADCValue());
		printf("Livetime     = %d\n", channelModule->getLivetime());
		printf("TriggerMode  = %d\n", channelModule->getTriggerMode());
		cout << channelModule->getStatus() << endl;

		size_t eventFIFODataCount = adcBoard->getRMAPHandler()->getRegister(AddressOf_EventFIFO_DataCountRegister);
		printf("EventFIFO Count = %zu\n", eventFIFODataCount);
		printf("TriggerCount = %zu\n", channelModule->getTriggerCount());
		printf("ADC          = %d\n", channelModule->getCurrentADCValue());

		//---------------------------------------------
		// Read events
		//---------------------------------------------
		size_t nEvents = 0;

#ifdef USE_ROOT
		TH1D* hist = new TH1D("h", "Histogram", 1024, 0, 1024);
#endif

#ifdef DRAW_CANVAS
		hist->GetXaxis()->SetRangeUser(480, 1024);
		hist->GetXaxis()->SetTitle("ADC Channel");
		hist->GetYaxis()->SetTitle("Counts");
		hist->Draw();
		canvas->Update();
//	RootEventLoop eventloop(app);
//	eventloop.start();

		size_t canvasUpdateCounter = 0;
		const size_t canvasUpdateCounterMax = 10;
#endif
		uint32_t elapsedTime = 0;
		while (elapsedTime < this->exposureInSec) {
			std::vector<SpaceFibreADC::Event*> events = adcBoard->getEvent();
			cout << "Received " << events.size() << " events" << endl;
			eventListFile->fillEvents(events);
#ifdef USE_ROOT
			for (auto event : events) {
				hist->Fill(event->phaMax);
			}
#endif
			nEvents += events.size();
			cout << events.size() << " events (" << nEvents << ")" << endl;
			adcBoard->freeEvents(events);
			c.wait(50);

#ifdef DRAW_CANVAS
			canvasUpdateCounter++;
			if (canvasUpdateCounter == canvasUpdateCounterMax) {
				cout << "Update canvas." << endl;
				canvasUpdateCounter = 0;
				hist->Draw();
				canvas->Update();
			}
#endif
			elapsedTime = CxxUtilities::Time::getUNIXTimeAsUInt32() - startTime_unixTime;
		}

		cout << "Saving event list" << endl;
		eventListFile->close();
		delete eventListFile;

#ifdef USE_ROOT
		cout << "Saving histogram" << endl;
		TFile* file = new TFile("hist.root", "recreate");
		file->cd();
		hist->Write();
		file->Close();
#endif

		adcBoard->stopAcquisition();
		adcBoard->closeDevice();
		cout << "Waiting child threads to be finalized..." << endl;
		c.wait(1000);
		cout << "Deleting ADCBoard instance." << endl;
		delete adcBoard;

#ifdef DRAW_CANVAS
		cout << "Terminating ROOT event loop." << endl;
		canvas->Close();
		delete canvas;
		app->Terminate(0);
		gROOT->ProcessLine(".q");
#endif
	}

};

int main(int argc, char* argv[]) {
	using namespace std;
	if (argc < 4) {
		cerr << "Provide UART device name (e.g. /dev/tty.usb-aaa-bbb), YAML configuration file, and exposure.." << endl;
		::exit(-1);
	}
	std::string deviceName(argv[1]);
	std::string configurationFile(argv[2]);
	double exposureInSec = atoi(argv[3]);
#ifdef DRAW_CANVAS
	app = new TApplication("app", &argc, argv);
#endif

	MainThread* mainThread = new MainThread(deviceName, configurationFile, exposureInSec);

#ifdef DRAW_CANVAS
	mainThread->start();
	app->Run(true);
#else
	mainThread->run();
	mainThread->join();
#endif
	return 0;
}

