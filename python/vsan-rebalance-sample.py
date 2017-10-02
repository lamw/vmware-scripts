#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
VSAN Management SDK sample exercising VSAN rebalance operation

Please use with extereme caution as this can potentially impact
the performance of your existing workload

Usage:
    python vsan-rebalance-sample.py -s 192.168.1.51 \
        -u 'administrator@vsphere.local' -p 'VMware1!' \
        -c VSAN-Cluster --operation get

    python vsan-rebalance-sample.py -s 192.168.1.51 \
        -u 'administrator@vsphere.local' -p 'VMware1!' \
        -c VSAN-Cluster --operation start

    python vsan-rebalance-sample.py -s 192.168.1.51 \
        -u 'administrator@vsphere.local' -p 'VMware1!' \
        -c VSAN-Cluster --operation stop
"""

__author__ = 'VMware, Inc'
from pyVim.connect import SmartConnect, Disconnect
import sys
import ssl
import atexit
import argparse
import getpass
# import the VSAN API python bindings
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
    parser.add_argument('-c', '--cluster', dest='clusterName', required=True,
                        action='store')
    parser.add_argument('-op', '--operation', dest='operation', required=True,
                        action='store')
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


def isRebalancing(vchs, clusterName):
    return vchs.VsanHealthIsRebalanceRunning(cluster=clusterName)


# Start program
def main():

    args = GetArgs()
    if args.password:
        password = args.password
    else:
        password = getpass.getpass(prompt='Enter password for host %s and '
                                   'user %s: ' % (args.host, args.user))

    # For python 2.7.9 and later, the defaul SSL conext has more strict
    # connection handshaking rule. We may need turn of the hostname checking
    # and client side cert verification
    context = None
    if sys.version_info[:3] > (2, 7, 8):
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

    si = SmartConnect(host=args.host,
                      user=args.user,
                      pwd=password,
                      port=int(args.port),
                      sslContext=context)

    atexit.register(Disconnect, si)

    # for detecting whether the host is VC or ESXi
    aboutInfo = si.content.about

    if aboutInfo.apiType == 'VirtualCenter':
        majorApiVersion = aboutInfo.apiVersion.split('.')[0]
        if int(majorApiVersion) < 6:
            print('The Virtual Center with version %s (lower than 6.0) \
                   is not supported.' % aboutInfo.apiVersion)
            return -1

        # Here is an example of how to access VC side VSAN Health Service API
        vcMos = vsanapiutils.GetVsanVcMos(si._stub, context=context)

        vchs = vcMos['vsan-cluster-health-system']

        cluster = getClusterInstance(args.clusterName, si)

        if cluster is None:
            print("Cluster %s is not found for %s" % (args.clusterName,
                  args.host))
            return -1

        if args.operation == "get":
            results = isRebalancing(vchs, cluster)
            print("%s rebalancing: %s \n" % (args.clusterName, results))
        elif args.operation == "start":
            if not isRebalancing(vchs, cluster):
                print("Starting rebalancing operation on %s cluster ..."
                      % args.clusterName)
                vsanTask = vchs.VsanRebalanceCluster(cluster=cluster)
                vcTask = vsanapiutils.ConvertVsanTaskToVcTask(vsanTask,
                                                              si._stub)
                vsanapiutils.WaitForTasks([vcTask], si)
            else:
                print("Rebalancing operation is already currently in progress")
        elif args.operation == "stop":
            if isRebalancing(vchs, cluster):
                print("Stopping rebalancing operation on %s cluster ..."
                      % args.clusterName)
                vsanTask = vchs.VsanStopRebalanceCluster(cluster=cluster)
                vcTask = vsanapiutils.ConvertVsanTaskToVcTask(vsanTask,
                                                              si._stub)
                vsanapiutils.WaitForTasks([vcTask], si)
            else:
                print("The rebalancing operation is currently not running")

# Start program
if __name__ == "__main__":
    main()
