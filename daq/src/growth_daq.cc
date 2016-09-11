/** Top-level file of the GROWTH Gamma-ray/particle event acquisition program.
 */
#include "MainThread.hh"
#include "MessageServer.hh"

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
