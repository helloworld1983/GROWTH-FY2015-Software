# GROWTH Detector Controller

- Runs as daemon
- Accepts commands via ZeroMQ
- Starts/stops DAQ

## ZeroMQ sockets

|TCP Port | Server |
|:-------:|:------:|
|10000    | growth_controller.rb |
|10010    | growth_display_server.py |

