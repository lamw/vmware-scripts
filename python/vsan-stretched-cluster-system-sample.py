#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""

An example of accessing new VSAN 6.2 API - VSAN Stretched Cluster System
http://pubs.vmware.com/vsphere-60/index.jsp?topic=%2Fcom.vmware.vsan.apiref.doc%2Fvim.cluster.VsanVcStretchedClusterSystem.html

This sample exercises the VSANVcGetWitnessHosts() API to retrieve all VSAN Witness Hosts for a given VSAN Cluster

"""

__author__ = 'William Lam'
from pyVmomi import vim
from pyVim.connect import SmartConnect, Disconnect
from requests.packages.urllib3.exceptions import InsecureRequestWarning
import sys
import ssl
import atexit
import argparse
import getpass
import requests
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

      #Here is an example of how to access VC side VSAN API
      vcMos = vsanapiutils.GetVsanVcMos(si._stub, context=context)
      # Get VSAN Stretched Cluster System
      vscs = vcMos['vsan-stretched-cluster-system']

      cluster = getClusterInstance(args.clusterName, si)

      if cluster is None:
          print("Cluster %s is not found for %s" % (args.clusterName, args.host))
          return -1

      # Retrieve Witness Host for given VSAN Cluster
      witnessHosts = vscs.VSANVcGetWitnessHosts(cluster=cluster)

      print("\nVSAN Witness VM for %s" % args.clusterName)
      for withnessHost in witnessHosts:
        host = (vim.HostSystem(withnessHost.host._moId,si._stub))
        print("Host: %s" % host.name)
        print("Node UUID: %s" % withnessHost.nodeUuid)
        print("Prefer Fault Domain: %s\n" % withnessHost.preferredFdName)

# Start program
if __name__ == "__main__":
   main()
