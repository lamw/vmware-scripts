#!/usr/bin/python
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vSphere
# Description: pyvmomi script that generates ESXi support bundles running from VCSA using vCenter Alarm
# Reference: http://www.williamlam.com/2016/06/how-to-run-a-script-from-a-vcenter-alarm-action-in-the-vcsa.html

import atexit
import argparse
import getpass
import logging
import os
import socket
import subprocess
import sys
import time
import urllib
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

      # Get Diag Manager which is used to generate support bundles in VC
      diagManager = content.diagnosticManager

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

      # Retrieve all ESXi hosts in the vSphere Cluster
      # to generate log bundles for
      hosts_to_generate_logs = []  
      hosts = cluster_view.host
      for h in hosts:
         hosts_to_generate_logs.append(h)

      # Generate log bundle excluding VC logs
      vcAlarmLog.info("Generating support bundle")
      print "Generating support bundle"
      task = diagManager.GenerateLogBundles_Task(includeDefault=False,host=hosts_to_generate_logs)

      task_done = False
      result = None 
      while not task_done:
         if task.info.state == "success":
            result = task.info.result
	    task_done = True
         if task.info.state == "error":
            vcAlarmLog.error("An error occured while generating support logs")
            print "An error occured while generating support logs"
            vcAlarmLog.error(task.info)
            print task.info
            return -1
            task_done = True
         if task.info.state == "running":
            time.sleep(60)

      # Path to which logs will be stored (automatically creating /esxi-support-logs dir)
      dir = args.filepath + "/esxi-support-logs"

      try:
         os.stat(dir)
      except:
         vcAlarmLog.info("Creating directory " + dir + " to store support bundle")
         os.mkdir(dir) 

      # Loop through the result to get the download URL for each
      # ESXi support bundle and save it to VCSA filesystem
      for file in result:
         download_url = file.url
         download_file = dir + "/vmsupport-" + file.system.name + ".tgz"

         vcAlarmLog.info("Downloading " + download_url + " to " + download_file)
         print "Downloading " + download_url + " to " + download_file
         urllib.urlretrieve(download_url,download_file)

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
