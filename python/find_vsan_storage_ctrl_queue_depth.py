#!/usr/bin/env python
# William Lam
# www.virtuallyghetto.com
# This script extracts the queue depth of a VSAN Storage Controller if found in the VSAN HCL (offline list)

import json
import os
from xml.etree import ElementTree as ET

show_non_vsan_hcl_ctr = False

#VSAN HCL Supported Controllers
vsan_controllers = '{"1000:005B:1000:9276": "MegaRAID SAS 9271-4i", "1000:0087:1590:0041": "H220", "1000:005B:1014:041D": "ServeRAID M5115 SAS/SATA Controller for IBM Flex System (90Y4390)", "1000:0087:1590:0043": "H222", "1000:0087:1590:0044": "H220i", "1000:0079:1000:9264": "LSI MegaRAID SAS 9264-8i", "1000:005B:8086:351D": "Intel RAID Controller RMS25CB080N", "1000:005B:1000:1F31": "PERC H710P Adapter", "1000:005B:1000:9270": "MegaRAID SAS 9270-8i", "1000:005B:1000:8081": "Nytro MegaRAID NMR 8110-4i", "1000:005B:1734:11E6": "SAS RAID HDD Module w/o Cache (D2837C )", "1000:005B:1734:11E5": "SAS RAID HDD Module (D2816C )", "1000:005B:1734:11E4": "RAID Ctrl SAS 6G 1GB (D3116C)", "1000:0079:8086:9261": "Intel RAID Controller RS2BL080", "1000:0073:1028:1F4E": "PERC H310 Adapter", "1000:0079:1014:03b3": "ServeRAID M5025 SAS/SATA Controller (46M0830)", "1000:0079:1000:9261": "LSI MegaRAID SAS 9260-8i", "1000:0079:1000:9267": "LSI MegaRAID SAS 9260CV-4i", "1000:005B:8086:9265": "Intel RAID Controller RS25DB080", "1000:0087:1000:3040": "SAS9207-4i4e", "103C:323B:103c:3351": "Smart Array P420", "1000:0079:1000:9268": "LSI MegaRAID SAS 9260CV-8i", "1000:005D:1734:120B": "PRAID CM400i", "103C:323B:103c:3354": "Smart Array P420i", "1000:0087:1000:3020": "SAS9207-8i", "1000:0073:1137:0073": "LSI SAS2008", "1000:0073:1137:0072": "LSI SAS2004", "103c:323b:103c:3353": "Smart Array P822", "1000:005B:1000:9269": "MegaRAID SAS 9266-4i", "1000:0070:1000:3010": "SAS9211-4i", "1000:0065:1000:30C0": "SAS9201-16i", "103C:323B:103c:3355": "Smart Array P220i", "1000:0079:1000:9263": "LSI MegaRAID SAS 9261-8i", "1000:0079:15d9:0070": "SMC2108", "1000:0072:1000:3050": "SAS9211-8i", "1000:005B:1028:1F35": "PERC H710 Adapter", "1000:005B:15d9:0690": "SMC2208", "1000:0079:1000:9282": "LSI MegaRAID SAS 9280-4i4e", "1000:005B:1000:9275": "MegaRAID SAS 9271-8iCC", "1000:005B:1000:9268": "MegaRAID SAS 9265CV-8i", "1000:005B:1014:040B": "ServeRAID M5110 SAS/SATA Controller for IBM System x (81Y4481)", "1000:0087:1000:3060": "SAS9217-4i4e", "1000:005b:1137:008d": "LSI 2208R", "1000:0073:1000:9240": "LSI MegaRAID SAS 9240-8i", "1000:0072:1000:3020": "SAS9211-8i", "1000:0072:1000:3060": "SAS9212-4i4e", "1000:0079:1000:9277": "LSI MegaRAID SAS 9280-16i4e", "1000:005B:1734:11D3": "RAID Ctrl SAS 6G 1GB (D3116)", "1000:005B:1734:11D4": "SAS RAID HDD Module (D2816)", "1000:005B:1734:11D5": "SAS RAID HDD Module w/o Cache (D2837)", "1000:0087:1000:3050": "SAS9217-8i", "1000:0079:8086:9276": "Intel RAID Controller RS2WG160", "1000:0079:1014:03c7": "IBM ServeRAID-M5014 SAS/SATA Controller", "1000:005B:1000:9267": "MegaRAID SAS 9267-8i", "1000:005B:1000:9266": "MegaRAID SAS 9266-8i", "1000:005B:1000:9265": "MegaRAID SAS 9265-8i", "1000:0086:15d9:0691": "SMC2308", "1000:0079:8086:9290": "Intel RAID Controller RS2SG244", "1000:005F:1734:1211": "PRAID CP400i", "1000:0087:8086:3060": "Intel RAID Controller RS25FB044", "1000:005B:8086:351C": "Intel RAID Controller RMS25PB080N", "1000:0073:1137:00c2": "Cisco UCS-E MegaRAID SAS 2004 ROMB", "1000:0087:8086:3518": "Intel RAID Controller RMS25KB080", "1000:0087:8086:3519": "Intel RAID Controller RMS25KB040", "1000:005D:1734:1209": "PRAID EM400i", "1000:0079:1000:9262": "LSI MegaRAID SAS 9262-8i", "1000:0073:1000:92A1": "LSI MegaRAID SAS 9240-8i", "1000:0079:1734:1176": "RAID Crtl SAS 6G 5/6 512MB", "1000:005B:1000:9271": "MegaRAID SAS 9271-8i", "1000:0079:8086:350B": "Intel RAID Controller RMS2MH080", "1000:005B:8086:3510": "Intel RAID Controller RMS25PB080", "1000:0079:1000:9276": "LSI MegaRAID SAS 9260-16i", "1000:0087:8087:3516": "Intel RAID Controller RMS25JB080", "1000:005B:1000:9272": "MegaRAID SAS 9272-8i", "1000:0079:8086:350D": "Intel RAID Controller RMS2AF040", "1000:0072:1000:3040": "SAS9210-8i", "1000:0079:1014:0411": "ServeRAID M5016 SAS/SATA Controller for IBM System x (90Y4304)", "1000:005b:1000:9273": "MegaRAID SAS 9270CV-8i", "1000:0087:8086:3517": "Intel RAID Controller RMS25JB040", "1000:0079:8086:350C": "Intel RAID Controller RMS2AF080", "1000:005B:8086:3514": "Intel RAID Controller RMS25CB040", "1000:005B:8086:3515": "Intel RAID Controller RMS25CB080", "1000:0072:1028:1F1D": "Dell PERC H200 Adapter", "1000:0079:1734:11B3": "PY SAS RAID Mezz Card 6Gb", "1000:0079:1000:9290": "LSI MegaRAID SAS 9280-24i4e"}'
json_data = json.loads(vsan_controllers)

#run esxcfg-info -s -F xml and store output to /tmp/esxcfginfo.xml
os.system("esxcfg-info -s -F xml > /tmp/esxcfginfo.xml")

# Load up XML output
root = ET.parse("/tmp/esxcfginfo.xml").getroot()

# SCSI Adatpers root starts at 'all-scsi-iface'
for allscsiadapters in root.findall('all-scsi-iface'):
	for allscsiadapter in allscsiadapters:
		scsiinterfaces = allscsiadapter.find('scsi-interface')
		for scsiinterface in scsiinterfaces:
			if scsiinterface.get('name') == 'queue-depth':
				queue_depth = scsiinterface.text
				pcidevices = scsiinterfaces.find('pci-device')
				if pcidevices != None: 
					for pcidevice in pcidevices:
						if pcidevice.get('name') == 'vendor-id':
							vendor_id = pcidevice.text
						if pcidevice.get('name') == 'device-id':
							device_id = pcidevice.text
						if pcidevice.get('name') == 'sub-vendor-id':
							sub_vendor_id = pcidevice.text
						if pcidevice.get('name') == 'sub-device-id':
							sub_device_id = pcidevice.text
						if pcidevice.get('name') == 'vendor-name':
							vendor_name = pcidevice.text
						if pcidevice.get('name') == 'device-name':
							device_name = pcidevice.text
					# used for non-VSAN HCL storage controllers
					adapter = vendor_name + " " + device_name
					custom_pci_id = (vendor_id + ":" + device_id  + ":" + sub_vendor_id + ":" + sub_device_id).replace('0x','')

					if custom_pci_id in json_data:
						print "VSAN HCL: Yes"
						print "Adapter: " + json_data[custom_pci_id]
						print "Identifer: " + custom_pci_id 
						print "QueueDepth: " + queue_depth + "\n"
					if show_non_vsan_hcl_ctr:
						print "VSAN HCL: No"
						print "Adapter: " + adapter
						print "Identifer: " + custom_pci_id 
						print "QueueDepth: " + queue_depth + "\n"
