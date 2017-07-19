#!/bin/bash

# install required packages
apt-get update -y && apt-get install -y --no-install-recommends wget ca-certificates

# retrieve test case data
mkdir /tmp/testfiles
wget -O /tmp/testfiles/xcms-find-peaks-data.rdata https://github.com/phnmnl/container-CAMERA/raw/develop/testfiles/xcms-find-peaks-data.rdata

# perform test case
/usr/local/bin/xsAnnotate.r input=/tmp/testfiles/xcms-find-peaks-data.rdata output=/tmp/camera-annotate-peaks-data.rdata
/usr/local/bin/groupFWHM.r input=/tmp/camera-annotate-peaks-data.rdata output=/tmp/camera-group-fwhm-data.rdata sigma=5 perfwhm=0.9 intval="maxo"
/usr/local/bin/findAdducts.r input=/tmp/camera-group-fwhm-data.rdata output=/tmp/camera-find-adducts-data.rdata ppm=15 polarity="positive" output.pdf=/tmp/camera-find-adducts-plot.pdf plotpdf=T rules="primary"

# check whether files were created
if [ ! -f /tmp/camera-annotate-peaks-data.rdata ]; then exit 1; fi
if [ ! -f /tmp/camera-group-fwhm-data.rdata ]; then exit 1; fi
if [ ! -f /tmp/camera-find-adducts-data.rdata ]; then exit 1; fi
if [ ! -f /tmp/camera-find-adducts-plot.pdf ]; then exit 1; fi

# remove files
rm /tmp/camera-annotate-peaks-data.rdata /tmp/camera-group-fwhm-data.rdata /tmp/camera-find-adducts-data.rdata /tmp/camera-find-adducts-plot.pdf
rm -r /tmp/testfiles
