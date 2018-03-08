#!/bin/bash

sudo ./usb-downloader -t slsiap -n raptor-32.txt -b bl1-usbboot.img
sleep 1
sudo ./usb-downloader -t slsiap -f fip-loader-usb.img -m
