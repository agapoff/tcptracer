install:
	install -d -m 755 ${DESTDIR}/opt/tcptracer
	install -d -m 755 ${DESTDIR}/var/log/tcptracer
	install -d -m 755 ${DESTDIR}/etc/logrotate.d
	install -d -m 755 ${DESTDIR}/usr/lib/systemd/system/
	install -m 755 src/tcptracer*  ${DESTDIR}/opt/tcptracer/
	install -m 755 src/config.ini  ${DESTDIR}/opt/tcptracer/
	install -m 755 logrotate.d/tcptracer  ${DESTDIR}/etc/logrotate.d/
	install -m 755 systemd/tcptracer.service ${DESTDIR}/usr/lib/systemd/system/
