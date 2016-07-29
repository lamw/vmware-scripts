#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Sample script leveraging the new VSAN Management 6.2 API
and VSAN Management SDK for Python to enable Compression/Dedupe capability
for a VSAN Cluster
"""

__author__ = 'William Lam'
from pyVmomi import vim
from pyVim.connect import SmartConnect, Disconnect
from requests.packages.urllib3.exceptions import InsecureRequestWarning
import atexit
import argparse
import getpass
import requests
import sys
import ssl
#import the VSAN API python bindings
import vsanmgmtObjects
import vsanapiutils

def GetArgs():
   """
   Supports the command-line arguments listed below.
   """
   parser = argparse.ArgumentParser(
       description='Process args for VSAN SDK sample application')
   parser.add_argument('-s', '--host', required=True, action='store',
                       help='Remote host to connect to')
   parser.add_argument('-o', '--port', type=int, default=443, action='store',
                       help='Port to connect on')
   parser.add_argument('-u', '--user', required=True, action='store',
                       help='User name to use when connecting to host')
   parser.add_argument('-p', '--password', required=False, action='store',
                       help='Password to use when connecting to host')
   parser.add_argument('--cluster', dest='clusterName', metavar="CLUSTER",
                      default='VSAN-Cluster')
   args = parser.parse_args()
   return args

def getClusterInstance(clusterName, serviceInstance):
   content = serviceInstance.RetrieveContent()
   searchIndex = content.searchIndex
   datacenters = content.rootFolder.childEntity
   for datacenter in datacenters:
      cluster = searchIndex.FindChild(datacenter.hostFolder, clusterName)
      if cluster is not None:
         return cluster
   return None

#Start program
def main():
   args = GetArgs()
   if args.password:
      password = args.password
   else:
      password = getpass.getpass(prompt='Enter password for host %s and '
                                        'user %s: ' % (args.host,args.user))

   #For python 2.7.9 and later, the defaul SSL conext has more strict
   #connection handshaking rule. We may need turn of the hostname checking
   #and client side cert verification
   context = None
   if sys.version_info[:3] > (2,7,8):
      context = ssl.create_default_context()
      context.check_hostname = False
      context.verify_mode = ssl.CERT_NONE

   # Disabling the annoying InsecureRequestWarning message
   requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

   si = SmartConnect(host=args.host,
                     user=args.user,
                     pwd=password,
                     port=int(args.port),
                     sslContext=context)

   atexit.register(Disconnect, si)

   #for detecting whether the host is VC or ESXi
   aboutInfo = si.content.about

   if aboutInfo.apiType == 'VirtualCenter':
      majorApiVersion = aboutInfo.apiVersion.split('.')[0]
      if int(majorApiVersion) < 6:
         print('The Virtual Center with version %s (lower than 6.0) is not supported.'
               % aboutInfo.apiVersion)
         return -1

      #Here is an example of how to access VC side VSAN Health Service API
      vcMos = vsanapiutils.GetVsanVcMos(si._stub, context=context)

      # Get VSAN Cluster Config System
      vccs = vcMos['vsan-cluster-config-system']

      cluster = getClusterInstance(args.clusterName, si)

      if cluster is None:
         print("Cluster %s is not found for %s" % (args.clusterName, args.host))
         return -1

      # Check to see if Automatic Claiming is enabled, if so, we need to disable else we can continue
      vsanCluster = vccs.VsanClusterGetConfig(cluster=cluster)

      if(vsanCluster.defaultConfig.autoClaimStorage == True):
         print ("Disabling Automatic Claiming on VSAN Cluster: %s" % args.clusterName)
         vsanSpec=vim.VimVsanReconfigSpec(
            vsanClusterConfig=vim.VsanClusterConfigInfo (
               defaultConfig=vim.VsanClusterConfigInfoHostDefaultInfo(
                  autoClaimStorage=False
               )
            ),
            modify=True
         )
         vsanTask = vccs.VsanClusterReconfig(cluster=cluster,vsanReconfigSpec=vsanSpec)
         vcTask = vsanapiutils.ConvertVsanTaskToVcTask(vsanTask,si._stub)
         vsanapiutils.WaitForTasks([vcTask],si)

      # Check to see if Dedupe & Compression is already enabled, if not, then we'll enable it
      if(vsanCluster.dataEfficiencyConfig.compressionEnabled == False or vsanCluster.dataEfficiencyConfig.dedupEnabled == False):
          print ("Enabling Compression/Dedupe capability on VSAN Cluster: %s" % args.clusterName)
          # Create new VSAN Reconfig Spec, both Compression/Dedupe must be enabled together
          vsanSpec = vim.VimVsanReconfigSpec(
             dataEfficiencyConfig=vim.VsanDataEfficiencyConfig(
                compressionEnabled=True,
                dedupEnabled=True
             ),
             modify=True
          )
          vsanTask = vccs.VsanClusterReconfig(cluster=cluster,vsanReconfigSpec=vsanSpec)
          vcTask = vsanapiutils.ConvertVsanTaskToVcTask(vsanTask,si._stub)
          vsanapiutils.WaitForTasks([vcTask],si)
      else:
        print ("Compression/Dedupe is already enabled on VSAN Cluster: %s" % args.clusterName)

# Start program
if __name__ == "__main__":
   main()
