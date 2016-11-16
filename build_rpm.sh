#!/bin/sh
PKG_NAME=`basename $(pwd)`
tar cvzf ../${PKG_NAME}.tar.gz --exclude=*/.git ../${PKG_NAME}/
rpmbuild --define "_topdir %(pwd)/../rpm-build" --define "_builddir %{_topdir}" --define "_rpmdir %{_topdir}" \
 --define '_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm' --define "vendor Quotix" -ta ../${PKG_NAME}.tar.gz
rm -f ../${PKG_NAME}.tar.gz
