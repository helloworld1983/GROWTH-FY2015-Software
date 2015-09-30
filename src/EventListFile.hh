/*
 * EventListFile.hh
 *
 *  Created on: Sep 29, 2015
 *      Author: yuasa
 */

#ifndef EVENTLISTFILE_HH_
#define EVENTLISTFILE_HH_

#include "CxxUtilities/CxxUtilities.hh"
#include "SpaceWireRMAPLibrary/Boards/SpaceFibreADCBoardModules/Types.hh"

/** Represents an event list file.
 */
class EventListFile {
private:
	std::string fileName;
	size_t nEntries = 0;

public:
	EventListFile(std::string fileName) :
			fileName(fileName) {
	}

public:
	virtual ~EventListFile() {

	}

public:
	virtual void fillEvents(std::vector<SpaceFibreADC::Event*>& events)=0;

public:
	virtual size_t getEntries() {
		return nEntries;
	}

public:
	virtual void close() =0;
};



#endif /* EVENTLISTFILE_HH_ */
