#!/usr/bin/python
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vSphere
# Description: pyvmomi script that generates ESXi performance support bundle connected to vCenter Server
# Reference: http://www.williamlam.com/2016/06/using-the-vsphere-api-to-remotely-generate-esxi-performance-support-bundles.html

import atexit
import argparse
import getpass
import logging
import os
import socket
import subprocess
import sys
import time
import urllib2
sys.path.extend(os.environ['VMWARE_PYTHON_PATH'].split(';'))

from pyVim import connect
from pyVmomi import vim
from pyVmomi import vmodl
from urlparse import urlparse

def get_args():
    """Get command line args from the user.
    """
    parser = argparse.ArgumentParser(
        description='Standard Arguments for talking to vCenter')

    parser.add_argument('-s', '--host',
                        #required=True,
                        default='localhost',
                        action='store',
                        help='Remote host to connect to')
    parser.add_argument('-o', '--port',
                        type=int,
                        default=443,
                        action='store',
                        help='Port to connect on')

    parser.add_argument('-u', '--user',
                        #required=True,
                        default='administrator@vghetto.local',
                        action='store',
                        help='User name to use when connecting to host')

    parser.add_argument('-p', '--password',
                        #required=False,
                        default='VMware1!',
                        action='store',
                        help='Password to use when connecting to host')

    parser.add_argument('-f', '--filepath',
                        default="/storage/log",
                        action='store',
                        help='Path on the VCSA to store vm-support files')

    parser.add_argument('-i', '--interval',
                        default=5,
                        action='store',
                        help='Number of intervals to run Performance snapshot')

    parser.add_argument('-d', '--duration',
                        default=60,
                        action='store',
                        help='Duration of each Performance snapshot')

    args = parser.parse_args()

    if not args.password:
        args.password = getpass.getpass(
            prompt='Enter SSO Admin password: ')

    return args

def main():
   """
   Simple pyvmomi (vSphere SDK for Python) script that generates ESXi support bundles running from VCSA using vCenter Alarm
   """

   # Logger for storing vCenter Alarm logs
   vcAlarmLog = logging.getLogger('vcenter_alarms')
   vcAlarmLog.setLevel(logging.INFO)
   vcAlarmLogFile = os.path.join('/var/log', 'vcenter_alarms.log')
   formatter = logging.Formatter("%(asctime)s;%(levelname)s;%(message)s","%Y-%m-%d %H:%M:%S")
   vcAlarmLogHandler = logging.FileHandler(vcAlarmLogFile)
   vcAlarmLogHandler.setFormatter(formatter)
   vcAlarmLog.addHandler(vcAlarmLogHandler)
   vcAlarmLog.propagate = False

   args = get_args()
   try:
      si = None
      try:
         si = connect.SmartConnect(host=args.host,
                user=args.user,
                pwd=args.password,
                port=int(args.port))
      except IOError, e:
        pass
      if not si:
         vcAlarmLog.info("Could not connect to the specified host using specified username and password")
         print "Could not connect to the specified host using specified username and password"
         return -1

      atexit.register(connect.Disconnect, si)

      content = si.RetrieveContent()

      # Get Session Manager which is used to request session ticket to an ESXi host
      sessionManager = content.sessionManager

      # Extract the vSphere Cluster generated from vCenter Server Alarm
      cluster = os.environ['VMWARE_ALARM_EVENT_COMPUTERESOURCE']
      #cluster = "Non-VSAN-Cluster"

      if cluster == None:
         vcAlarmLog.info("Unable to extract vSphere Cluster from VMWARE_ALARM_EVENT_COMPUTERESOURCE")
         print "Unable to extract vSphere Cluster from VMWARE_ALARM_EVENT_COMPUTERESOURCE"
         return -1

      vcAlarmLog.info("Cluster passed from VC Alarm: " + cluster)

      # Retrieve all vSphere Clusters
      container = content.viewManager.CreateContainerView(content.rootFolder,
                                                           [vim.ClusterComputeResource],
                                                           True)
      # Return vSphere Cluster that matches name specified
      for c in container.view:
          if c.name == cluster:
             cluster_view = c
             break

      container.Destroy()

      # Path to which logs will be stored (automatically creating /esxi-support-logs dir)
      dir = args.filepath + "/esxi-support-logs"

      try:
         os.stat(dir)
      except:
         vcAlarmLog.info("Creating directory " + dir + " to store support bundle")
         os.mkdir(dir)

      # Loop through all ESXi hosts in cluster to build performance bundle URL
      # Generate session ticket that can be used to download the file
      hosts = cluster_view.host
      for h in hosts:
         # URL to the ESXi specific Performance Support Bundle
         # https://192.168.1.190/cgi-bin/vm-support.cgi?performance=true&interval=5&duration=60
         url = "https://" + h.name + "/cgi-bin/vm-support.cgi?performance=true&interval=" + str(args.interval) + "&duration=" + str(args.duration)

         vcAlarmLog.info("Requesting Session Ticket for " + h.name)
         print "Requesting Session Ticket for " + h.name
         ticket = sessionManager.AcquireGenericServiceTicket(
            spec = vim.SessionManagerHttpServiceRequestSpec (
		url = url,
                method = "httpGet"
            )
         )

         # Append the cookie generated from VC
         cgi_cookie = "vmware_cgi_ticket=" + ticket.id
         opener = urllib2.build_opener()
         opener.addheaders.append(('Cookie', cgi_cookie))

         # Download Performance Support Bundle (may take some time for it to be generated)
         download_file = dir + "/vmsupport-" + h.name + ".tgz"
         vcAlarmLog.info("Waiting for Performance support bundle to be generated on " + h.name + " and downloaded to to " + download_file)
         print "Waiting for Performance support bundle to be generated on " + h.name + " and downloaded to to " + download_file
         f = opener.open(url)
         with open(download_file, "wb") as code:
            code.write(f.read())

   except vmodl.MethodFault, e:
      vcAlarmLog.error("Caught vmodl fault : " + e.msg)
      print "Caught vmodl fault : " + e.msg
      return -1
   except Exception, e:
      vcAlarmLog.error("Caught exception : " + str(e))
      print "Caught exception : " + str(e)
      return -1

   return 0

# Start program
if __name__ == "__main__":
    main()
