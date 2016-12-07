TCPtracer
=========

This project originates from Brendan Gregg's [perf-tools](https://github.com/brendangregg/perf-tools) project.

It traces for outgoing TCP retransmits while listening for tcp_retransmit_skb and tcp_send_loss_probe kernel functions. And then it writes all the retransmits with corresponding addresses, TCP ports and other relevant data taken from /proc/net/tcp to a file or to Elasticsearch. The output methods are implemented as modules so the tcptracer's functionality can be easily extended without any intervention into the main code.

The project is structured for building the RPM-package with SystemD unit-file. But you can easily use it as a standalone application on any recent Linux box with Ftrace enabled. Just copy everything from the src folder and you're done.

### Build the RPM package

1. Edit the SPEC-file if needed.
2. Run build-rpm.sh script.
3. PROFIT!!!

### Run the application

1. Edit config.ini for your needs.
2. If you have installed RPM-package with SystemD unit-file:
```
    systemctl start tcptracer
```
3. If you are using the standalone application:
```
    ./tcptracer.pl
```


### Contributing

Anyone and everyone is welcome to contribute. 


## Issues

Found a bug or want to request a new feature? Please submit an Issue on this repo.


## License

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

http://www.gnu.org/copyleft/gpl.html
