/*
 * EventListFileFITS.hh
 *
 *  Created on: Sep 30, 2015
 *      Author: yuasa
 */
#ifndef EVENTLISTFILEFITS_HH_
#define EVENTLISTFILEFITS_HH_

extern "C" {
#include "fitsio.h"
}

#include "CxxUtilities/FitsUtility.hh"

#include "EventListFile.hh"

class EventListFileFITS: public EventListFile {
private:
	fitsfile* outputFile;
	std::string detectorID;
	SpaceFibreADC::Event eventEntry;
	std::string configurationYAMLFile;

private:
	//---------------------------------------------
	// event list HDU
	//---------------------------------------------
	static const size_t nColumns = 6;
	char* ttypes[nColumns] = { //
			(char*) "boardIndexAndChannel", //
					(char*) "timeTag", //
					(char*) "triggerCount", //
					(char*) "liveTime", //
					(char*) "phaMax", //
					(char*) "waveform" //
			};
	const size_t MaxTFORM = 1024;
	char* tforms[nColumns] = { //
			(char*) "B"/*uint8_t*/, //
					(char*) "K"/*uint64_t*/, //
					(char*) "U"/*uint16_t*/, //
					(char*) "U"/*uint16_t*/, //
					(char*) "U"/*uint16_t*/, //
					new char[MaxTFORM] /* to be filled later */ //
			};
	char* tunits[nColumns] = { //
			(char*) "", (char*) "", (char*) "", (char*) "", (char*) "", (char*) "" //
			};
	enum columnIndices {
		Column_boardIndexAndChannel = 1,
		Column_timeTag = 2,
		Column_triggerCount = 3,
		Column_liveTime = 4,
		Column_phaMax = 5,
		Column_waveform = 6
	};

	//---------------------------------------------
	// GPS Time Register HDU
	//---------------------------------------------
	static const size_t nColumns_GPS = 3;
	char* ttypes_GPS[nColumns_GPS] = { //
			(char*) "fpgaTimeTag", //
			(char*) "unixTime", //
					(char*) "gpsTime" //
			};
	char* tforms_GPS[nColumns_GPS] = { //
			(char*) "K", //
			(char*) "V", //
					(char*) "20A" //
			};
	char* tunits_GPS[nColumns_GPS] = { //
			(char*) "", //
			(char*) "", //
					(char*) "" //
			};
	enum columnIndices_GPS {
		Column_fpgaTimeTag = 1, //
		Column_unixTime = 2, //
		Column_gpsTime = 3
	};

private:
	static const size_t InitialRowNumber = 1000;
	static const size_t InitialRowNumber_GPS = 1000;
	int fitsStatus = 0;
	bool outputFileIsOpen = false;
	size_t rowIndex; // will be initialized in createOutputFITSFile()
	size_t rowIndex_GPS; // will be initialized in createOutputFITSFile()
	size_t fitsNRows; //currently allocated rows
	size_t rowExpansionStep = InitialRowNumber;
	size_t nSamples;

private:
	CxxUtilities::Mutex fitsAccessMutes;

public:
	EventListFileFITS(std::string fileName, std::string detectorID = "empty", std::string configurationYAMLFile = "",
			size_t nSamples = 1024) :
			EventListFile(fileName), detectorID(detectorID), nSamples(nSamples), configurationYAMLFile(configurationYAMLFile) {
		createOutputFITSFile();
	}

private:
	void createOutputFITSFile() {
		fitsAccessMutes.lock();
		using namespace std;

		rowIndex = 0;
		rowIndex_GPS = 0;

		std::stringstream ss;
		ss << this->nSamples << "U";
		strcpy(tforms[5], ss.str().c_str());

		long nRows = InitialRowNumber;
		fitsNRows = InitialRowNumber;
		long naxis = 1;
		long naxes[1] = { 1 };
		int tbltype = BINARY_TBL;
		// Create FITS File
		if (fileName[0] != '!') {
			fileName = "!" + fileName;
		}
		fits_create_file(&outputFile, fileName.c_str(), &fitsStatus);
		this->reportErrorThenQuitIfError(fitsStatus, __func__);

		// Create FITS Image
		fits_create_img(outputFile, USHORT_IMG, naxis, naxes, &fitsStatus);
		this->reportErrorThenQuitIfError(fitsStatus, __func__);

		// Create BINTABLE
		fits_create_tbl(outputFile, tbltype, nRows, nColumns, ttypes, tforms, tunits, "EVENTS", &fitsStatus);
		this->reportErrorThenQuitIfError(fitsStatus, __func__);

		//write header info
		writeHeader();

		// Create GPS Time HDU
		fits_create_tbl(outputFile, tbltype, InitialRowNumber_GPS, nColumns_GPS, ttypes_GPS, tforms_GPS, tunits_GPS, "GPS",
				&fitsStatus);
		this->reportErrorThenQuitIfError(fitsStatus, __func__);

		fits_movnam_hdu(outputFile, tbltype, (char*) "EVENTS", 0, &fitsStatus);
		this->reportErrorThenQuitIfError(fitsStatus, __func__);

		outputFileIsOpen = true;
		fitsAccessMutes.unlock();
	}

public:
	~EventListFileFITS() {
		close();
	}

private:
	void writeHeader() {
		/* sample code
		 fits_update_key_str_check(fp, n=(char*)"TELESCOP", v->telescop, c->telescop, &istat)||
		 fits_update_key_fixdbl(fp, n=(char*)"dec_pnt", v->dec_pnt, 8, c->dec_pnt, &istat)||
		 fits_update_key_lng(fp, n=(char*)"EQUINOX", v->equinox, c->equinox, &istat)||
		 *
		 */

		char* n; //keyword name
		std::string creationDate = CxxUtilities::Time::getCurrentTimeYYYYMMDD_HHMMSS();
		long NSAMPLES = this->nSamples;
		if ( //
				 //fileCreationDate
		fits_update_key_str(outputFile, n = (char*) "FILEDATE", (char*) creationDate.c_str(), "fileCreationDate",
				&fitsStatus) || //
				//detectorID
				fits_update_key_str(outputFile, n = (char*) "DET_ID", (char*) this->detectorID.c_str(), "detectorID",
						&fitsStatus) || //
				//nSamples
				fits_update_key_lng(outputFile, n = (char*) "NSAMPLES", NSAMPLES, "nSamples", &fitsStatus) //
						) {
			using namespace std;
			cerr << "Error: while updating TTYPE comment for " << n << endl;
			exit(-1);
		}

		//configurationYAML as HISTORY
		if (configurationYAMLFile != "") {
			std::vector<std::string> lines = CxxUtilities::File::getAllLines(configurationYAMLFile);
			for (auto line : lines) {
				line = "YAML-- " + line;
				fits_write_history(outputFile, (char*) line.c_str(), &fitsStatus);
			}
		}
	}

private:
	void reportErrorThenQuitIfError(int fitsStatus, std::string methodName) {
		if (fitsStatus) { //if error
			using namespace std;
			cerr << "Error (" << methodName << "):";
			fits_report_error(stderr, fitsStatus);
			exit(-1);
		}
	}

private:
	const int firstElement = 1;

public:
	/** Fill an entry to the HDU containing GPS Time and FPGA Time Tag.
	 * Length of the data should be the same as GROWTH_FY2015_ADC::LengthOfGPSTimeRegister.
	 * @param[in] buffer buffer containing a GPS Time Register data
	 */
	void fillGPSTime(uint8_t* gpsTimeRegisterBuffer) {
		// 0123456789X123456789
		// GPYYMMDDHHMMSSxxxxxx
		long long timeTag = 0;
		for (size_t i = 14; i < GROWTH_FY2015_ADC::LengthOfGPSTimeRegister; i++) {
			timeTag = gpsTimeRegisterBuffer[i] + (timeTag << 8);
		}
		fitsAccessMutes.lock();
		//move to GPS HDU
		fits_movnam_hdu(outputFile, BINARY_TBL, (char*) "GPS", 0, &fitsStatus);
		this->reportErrorThenQuitIfError(fitsStatus, __func__);

		rowIndex_GPS++;

		/* dump date
		using namespace std;
		cout << "YY/MM/DD HH:MM:DD = " << gpsTimeRegisterBuffer[2] << gpsTimeRegisterBuffer[3] << "/" //
				<< gpsTimeRegisterBuffer[4] << gpsTimeRegisterBuffer[5] << "/" //
				<< gpsTimeRegisterBuffer[6] << gpsTimeRegisterBuffer[7] << " " //
				<< gpsTimeRegisterBuffer[8] << gpsTimeRegisterBuffer[9] << ":" //
				<< gpsTimeRegisterBuffer[10] << gpsTimeRegisterBuffer[11] << ":" //
				<< gpsTimeRegisterBuffer[12] << gpsTimeRegisterBuffer[13] << endl;
		 */

		//get unix time
		long unixTime=CxxUtilities::Time::getUNIXTimeAsUInt32();

		//write
		fits_write_col(outputFile, TLONGLONG, Column_fpgaTimeTag, rowIndex_GPS, firstElement, 1, &timeTag, &fitsStatus);
		fits_write_col(outputFile, TLONG, Column_unixTime, rowIndex_GPS, firstElement, 1, &unixTime, &fitsStatus);
		fits_write_col(outputFile, TSTRING, Column_gpsTime, rowIndex_GPS, firstElement, 1 /* YYMMDDHHMMSS */,
				&gpsTimeRegisterBuffer, &fitsStatus);

		//move back to EVENTS HDU
		fits_movnam_hdu(outputFile, BINARY_TBL, (char*) "EVENTS", 0, &fitsStatus);
		this->reportErrorThenQuitIfError(fitsStatus, __func__);
		fitsAccessMutes.unlock();
	}

public:
	void fillEvents(std::vector<SpaceFibreADC::Event*>& events) {
		fitsAccessMutes.lock();
		for (auto& event : events) {
			rowIndex++;
			//ch
			fits_write_col(outputFile, TBYTE, Column_boardIndexAndChannel, rowIndex, firstElement, 1, &event->ch,
					&fitsStatus);
			//timeTag
			fits_write_col(outputFile, TLONGLONG, Column_timeTag, rowIndex, firstElement, 1, &event->timeTag, &fitsStatus);
			//triggerCount
			fits_write_col(outputFile, TUSHORT, Column_triggerCount, rowIndex, firstElement, 1, &event->triggerCount,
					&fitsStatus);
			//liveTime
			fits_write_col(outputFile, TUSHORT, Column_liveTime, rowIndex, firstElement, 1, &event->livetime, &fitsStatus);
			//phaMax
			fits_write_col(outputFile, TUSHORT, Column_phaMax, rowIndex, firstElement, 1, &event->phaMax, &fitsStatus);
			//waveform
			fits_write_col(outputFile, TUSHORT, Column_waveform, rowIndex, firstElement, nSamples, event->waveform,
					&fitsStatus);

			//
			expandIfNecessary();
		}
		fitsAccessMutes.unlock();
	}

private:
	void expandIfNecessary() {
		using namespace std;
		int fitsStatus = 0;
		//check heap size, and expand row size if necessary (to avoid slow down of cfitsio)
		while (rowIndex > fitsNRows) {
			fits_flush_file(outputFile, &fitsStatus);
			fits_insert_rows(outputFile, fitsNRows + 1, rowExpansionStep - 1, &fitsStatus);
			this->reportErrorThenQuitIfError(fitsStatus, __func__);

			long nRowsGot = 0;
			fits_get_num_rows(outputFile, &nRowsGot, &fitsStatus);
			this->reportErrorThenQuitIfError(fitsStatus, __func__);
			fitsNRows = nRowsGot;

			rowExpansionStep = rowExpansionStep * 2;
			cout << "Output FITS file was resized to " << dec << fitsNRows << " rows." << endl;
		}
	}

public:
	size_t getEntries() {
		return rowIndex;
	}

public:
	void close() {
		if (outputFileIsOpen) {
			fitsAccessMutes.lock();
			outputFileIsOpen = false;
			using namespace std;
			int fitsStatus = 0;

			uint32_t nUnusedRow = fitsNRows - rowIndex;
			cout << "Closing the current output file." << endl;
			cout << " rowIndex    = " << dec << rowIndex << " (number of filled rows)" << endl;
			cout << " fitsNRows   = " << dec << fitsNRows << " (allocated row number)" << endl;
			cout << " unused rows = " << dec << nUnusedRow << endl;

			/* Delete unfilled rows. */
			fits_flush_file(outputFile, &fitsStatus);
			this->reportErrorThenQuitIfError(fitsStatus, __func__);
			if (fitsNRows != rowIndex) {
				cout << "Deleting unused " << nUnusedRow << " rows." << endl;
				fits_delete_rows(outputFile, rowIndex + 1, nUnusedRow, &fitsStatus);
				this->reportErrorThenQuitIfError(fitsStatus, __func__);
			}

			/* Recover unused heap. */
			cout << "Recovering unused heap." << endl;
			fits_compress_heap(outputFile, &fitsStatus);
			this->reportErrorThenQuitIfError(fitsStatus, __func__);

			/* Write date. */
			cout << "Writing data to file." << endl;
			fits_write_date(outputFile, &fitsStatus);
			this->reportErrorThenQuitIfError(fitsStatus, __func__);

			/* Update NAXIS2 */
			if (rowIndex == 0) {
				fits_update_key(outputFile, TULONG, (char*) "NAXIS2", (void*) &rowIndex, (char*) "number of rows in table",
						&fitsStatus);
				this->reportErrorThenQuitIfError(fitsStatus, __func__);
				cout << "This HDU has 0 row." << endl;
			}

			/* Update checksum. */
			cout << "Updating ch ecksum." << endl;
			fits_write_chksum(outputFile, &fitsStatus);
			this->reportErrorThenQuitIfError(fitsStatus, __func__);

			/* Close FITS File */
			cout << "Closing file." << endl;
			fits_close_file(outputFile, &fitsStatus);
			this->reportErrorThenQuitIfError(fitsStatus, __func__);
			cout << "Output FITS file closed." << endl;

			fitsAccessMutes.unlock();
		}
	}
};

#endif /* EVENTLISTFILEFITS_HH_ */
