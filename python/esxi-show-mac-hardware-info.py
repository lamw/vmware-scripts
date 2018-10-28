# **********************************************************
# Copyright (c) 2018 VMware, Inc.  All rights reserved.
# **********************************************************/

#
# esxi-show-mac-hardware-info.py --
#
#      This module displays various pieces of hardware information potentially
#      useful (and otherwise difficult to obtain) from Apple hardware.
#

import struct
import fcntl
import subprocess

def GetSerialId():
	return subprocess.check_output('smbiosDump | sed -ne \'/^  System Info:/,/^  [^ ]/ {/^    Serial: "\\(.*\\)"$/ {s//\\1/;p}}\'', shell=True, universal_newlines=True).strip()

def GetModelId():
	return subprocess.check_output('smbiosDump | sed -ne \'/^  System Info:/,/^  [^ ]/ {/^    Product: "\\(.*\\)"$/ {s//\\1/;p}}\'', shell=True, universal_newlines=True).strip()

def GetBoardId():
	return subprocess.check_output('smbiosDump | sed -ne \'/^  Board Info:/,/^  [^ ]/ {/^    Product: "\\(.*\\)"$/ {s//\\1/;p}}\'', shell=True, universal_newlines=True).strip()

def GetFirmwareVersion():
	return subprocess.check_output('smbiosDump | sed -ne \'/^  BIOS Info:/,/^  [^ ]/ {/^    Version: "\\(.*\\)"$/ {s//\\1/;p}}\'', shell=True, universal_newlines=True).strip()

def DisplayFirmwareVersion(versionString):
	# Segments 1, 3 and 4.
	fragments = versionString.split('.')
	return '.'.join((fragments[0], fragments[2], fragments[3]))

def GetSmcRevision():
	s = bytearray(b' VER\6' + 28 * b'\0')
	fd = open('/vmfs/devices/char/mem/applesmc', 'a+')
	fcntl.ioctl(fd, 0x4101, s, True)
	fd.close()
	if s[32] != 0:
		raise IOError('Failed: %d' % s[32])
	return '%x.%x%x%x' % (s[0], s[1], s[2], (s[3] << 16 | s[4] << 8 | s[5]))

print('\nModel Identifier:', GetModelId())
print('Serial ID:', GetSerialId())
print('Board ID:', GetBoardId())
firmwareVer = GetFirmwareVersion()
print('Boot ROM Version: %s (%s)' % (DisplayFirmwareVersion(firmwareVer), firmwareVer))
print('SMC Version:', GetSmcRevision())
print('\n')