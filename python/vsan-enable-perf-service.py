#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
vSAN Management SDK sample enabling
vSAN Performance Service https://dp-downloads.broadcom.com/api-content/apis/API_VMA_001/8.0U3/html/vim.cluster.VsanVcClusterConfigSystem.html#reconfigureEx

Usage:
    python vsan-enable-perf-service.py -s 10.0.0.1 \
        -u 'administrator@vsphere.local' -p 'VMware1!' \
        -c 'vsan-cluster-01'
"""

__author__ = 'VMware, Inc'
from pyVmomi import vim
from pyVim.connect import SmartConnect, Disconnect
import atexit
import argparse
import datetime
import getpass
import json
import random
import sys
import ssl
# import the VSAN API python bindings
import vsanmgmtObjects
import vsanapiutils


def GetArgs():
    """
    Supports the command-line arguments listed below.
    """

    parser = argparse.ArgumentParser(
        description='Process args for VSAN vSAN Performance Service Enabler')
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
    args = parser.parse_args()
    return args


def get_obj(content, vim_type, name=None):
    obj = None
    container = content.viewManager.CreateContainerView(
        content.rootFolder, vim_type, True)
    if name:
        for c in container.view:
            if c.name == name:
                obj = c
                return obj
    else:
        return container.view


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

    # Connect to VC/ESXi
    si = SmartConnect(host=args.host,
                    user=args.user,
                    pwd=password,
                    port=int(args.port),
                    sslContext=context)

    # Disconnect upon script exit
    atexit.register(Disconnect, si)

    # for detecting whether the host is VC or ESXi
    aboutInfo = si.content.about

    if aboutInfo.apiType == 'VirtualCenter':
        majorApiVersion = aboutInfo.apiVersion.split('.')[0]
        if int(majorApiVersion) < 6:
            print('The Virtual Center with version %s (lower than 6.0) \
                is not supported.' % aboutInfo.apiVersion)
            return -1

        # Retrieve the latest API version
        apiVersion = vsanapiutils.GetLatestVmodlVersion(args.host, int(args.port))

        vcMos = vsanapiutils.GetVsanVcMos(si._stub, context=context, version=apiVersion)
        vccs = vcMos['vsan-cluster-config-system']

        # Get cluster and check its existence
        cluster = get_obj(si.content,
                        [vim.ClusterComputeResource], args.clusterName)

        if cluster is None:
            print("Cluster %s is not found for %s" % (args.clusterName,
                args.host))
            return -1

        # Prepare specifications for how to configure the cluster
        perfSpec = vim.cluster.VsanPerfsvcConfig(enabled=True)
        vsanReconfigSpec = vim.vsan.ReconfigSpec(perfsvcConfig=perfSpec)

        # Reconfigure the vSAN cluster
        vsanTask = vccs.VsanClusterReconfig(cluster=cluster, vsanReconfigSpec=vsanReconfigSpec)
        print('Task ID: %s' % vsanTask)

        # Wait for task completion
        print('Waiting for task to complete...')
        vsanapiutils.WaitForTasks([vsanTask], si)

        # Check if task was successful
        print('Enabling vSAN PerfService task finished with status: %s' % vsanTask.info.state)
        if vsanTask.info.state == 'success':
            sys.exit(0)
        else:
            sys.exit(1)


# Start program
if __name__ == "__main__":
    main()
