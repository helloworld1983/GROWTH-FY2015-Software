/*
 * MessageServer.hh
 *
 *  Created on: Jun 26, 2016
 *      Author: Takayuki Yuasa
 */

#ifndef SRC_MESSAGESERVER_HH_
#define SRC_MESSAGESERVER_HH_

#include <iomanip>
#include <sstream>
#include "CxxUtilities/CxxUtilities.hh"

// ZeroMQ
#include <zmq.hpp>
#include <string>
#include <iostream>
#include <unistd.h>

// picojson
#include "picojson.h"

/** Receives message from a client, and process the message.
 * Typical messages include:
 * <ul>
 *   <li> {"command": "stop"}  => stop the target thread </li>
 * </ul>
 */
class MessageServer: public CxxUtilities::StoppableThread {
public:
  /** @param[in] targetThread a pointer of Thread instance which will be controlled by this thread
   */
  MessageServer(CxxUtilities::StoppableThread* targetThread) : //
      context(1), socket(context, ZMQ_REP), targetThread(targetThread) {
    std::stringstream ss;
    ss << "tcp://*:" << TCPPortNumber;
    int timeout = TimeOutInMilisecond;
    socket.setsockopt(ZMQ_RCVTIMEO, &timeout, sizeof(timeout));
    socket.bind(ss.str());
  }

public:
  ~MessageServer() {
  }

public:
  void run() {
    using namespace std;
    while (!stopped) {
      zmq::message_t request;
      //  Wait for next request from client
      if (socket.recv(&request)) {
        std::cout << "MessageServer: Received " << std::endl;
      } else {
        if (errno != EAGAIN) {
          cerr << "Error: MessageServer::run(): receive failed." << endl;
          ::exit(-1);
        } else {
#ifdef DEBUG_MESSAGESERVER
          cout << "MessageServer::run(): timed out. continue." << endl;
#endif
          continue;
        }
      }

      // Construct a string from received data
      std::string messagePayload;
      messagePayload.assign(static_cast<char*>(request.data()), request.size());
#ifdef DEBUG_MESSAGESERVER
      cout << "MessageServer::run(): received message" << endl;
      cout << messagePayload << endl;
      cout << endl;
#endif

      // Process received message
      processMessage(messagePayload);
    }
  }

private:
  void processMessage(const std::string& messagePayload) {
    using namespace std;
    picojson::value v;
    picojson::parse(v, messagePayload);
    if (v.is<picojson::object>()) {
#ifdef DEBUG_MESSAGESERVER
      cout << "MessageServer::processMessage(): received object is: {" << endl;
#endif
      for (auto& it : v.get<picojson::object>()) {
        cout << it.first << ": " << it.second.to_str() << endl;
        if (it.first == "command") {
          if (it.second.to_str() == "stop") {
#ifdef DEBUG_MESSAGESERVER
            cout << "MessageServer::processMessage(): stop command received." << endl;
#endif
            // Stop target thread and self
            targetThread->stop();
            this->stop();
          }
        }
      }
#ifdef DEBUG_MESSAGESERVER
      cout << "}";
#endif
    }
  }

public:
  static const uint16_t TCPPortNumber = 5555;
  static const int TimeOutInMilisecond = 1000; // 1 sec
private:
  zmq::context_t context;
  zmq::socket_t socket;
private:
  CxxUtilities::StoppableThread* targetThread;
};

#endif /* SRC_MESSAGESERVER_HH_ */
