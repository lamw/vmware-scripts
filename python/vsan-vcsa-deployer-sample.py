#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
VSAN 6.6 Management SDK sample exercising new VCSA deployer system

Usage:
    python vsan-vcsa-deployer-sample.py -s 192.168.1.100 \
        -u root -p 'VMware1!' \
        --operation listdisk

    python vsan-vcsa-deployer-sample.py -s 192.168.1.100 \
        -u root -p 'VMware1!' \
        --operation prepare \
        --cache "SAMSUNG MZVPV128" \
        --capacity "Samsung SSD 850"

    python vsan-vcsa-deployer-sample.py -s 192.168.1.200 \
        -u 'administrator@vsphere.local' -p 'VMware1!' \
        --operation postconfig \
        --datacenterName "VSAN-Datacenter" \
        --clusterName "VSAN-Cluster" \
        --esxIP 192.168.1.100 \
        --esxPassword 'VMware1!'
"""

__author__ = 'VMware, Inc'
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import sys
import ssl
import atexit
import argparse
import getpass
import time
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
    parser.add_argument('-op', '--operation', dest='operation', required=True,
                        action='store')
    parser.add_argument('-cap', '--capacity', dest='capacity', required=False,
                        action='store')
    parser.add_argument('-cac', '--cache', dest='cache', required=False,
                        action='store')
    parser.add_argument('-cl', '--clusterName', dest='clusterName',
                        required=False, action='store')
    parser.add_argument('-dc', '--datacenterName', dest='datacenterName',
                        required=False, action='store')
    parser.add_argument('-e', '--esxIP', dest='esxIP',
                        required=False, action='store')
    parser.add_argument('-ep', '--esxPassword', dest='esxPassword',
                        required=False, action='store')
    args = parser.parse_args()
    return args


def getESXInstance(serviceInstance):
    content = serviceInstance.RetrieveContent()
    container = content.viewManager.CreateContainerView(content.rootFolder,
                                                        [vim.HostSystem],
                                                        True)

    for c in container.view:
        if c is not None:
            return c
    return None


def trackBootstrapProgress(vvds, progress, taskId):
    while 1:
        if progress[0].success:
            print("Operation successfully completed\n")
            break
        else:
            print("Current Progress: %s%% - %s"
                  % (progress[0].progressPct, progress[0].message))
            time.sleep(30)
            progress = vvds.VsanVcsaGetBootstrapProgress(taskId=[taskId])


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

    if args.operation == "listdisk" or args.operation == "prepare":
        if aboutInfo.apiType == 'HostAgent':
            majorApiVersion = aboutInfo.apiVersion.split('.')[0]
            if int(majorApiVersion) < 6:
                print("This ESXi host has version %s (lower than 6.0) "
                      "is not supported." % aboutInfo.apiVersion)
                return -1

            vcMos = vsanapiutils.GetVsanEsxMos(si._stub, context=context)
            vvds = vcMos['vsan-vcsa-deployer-system']

            esx = getESXInstance(si)

            if args.operation == "listdisk":
                disks = esx.configManager.vsanSystem.QueryDisksForVsan()
                for disk in disks:
                    if(disk.state == "eligible"):
                        print("Vendor: %s" % disk.disk.vendor.strip())
                        print("Model : %s" % disk.disk.model.strip())
                        print("Name  : %s\n" % disk.disk.canonicalName.strip())
            if args.operation == "prepare":
                cacheDisk = None
                capacityDisk = None
                disks = esx.configManager.vsanSystem.QueryDisksForVsan()
                for disk in disks:
                    if(disk.disk.model.strip() == args.capacity):
                        capacityDisk = disk.disk
                    if(disk.disk.model.strip() == args.cache):
                        cacheDisk = disk.disk

                if cacheDisk is not None and capacityDisk is not None:
                    spec = vim.VsanPrepareVsanForVcsaSpec(
                        vsanDataEfficiencyConfig=vim.VsanDataEfficiencyConfig(
                            compressionEnabled=True,
                            dedupEnabled=True
                        ),
                        vsanDiskMappingCreationSpec=vim.VimVsanHostDiskMappingCreationSpec(
                            cacheDisks=[cacheDisk],
                            capacityDisks=[capacityDisk],
                            creationType="allFlash",
                            host=esx
                        )
                    )
                    print("\nPreparing ESXi host for VCSA Bootstrap ...")
                    taskId = vvds.VsanPrepareVsanForVcsa(spec=spec)
                    progress = vvds.VsanVcsaGetBootstrapProgress(
                        taskId=[taskId])
                    trackBootstrapProgress(vvds, progress, taskId)
                else:
                    print("Unable to locate either Cache "
                          "or Capacity disk for vSAN configuration")
                    return -1
        else:
            print("listdisk and prepare operation requires "
                  "that you connect an ESXi host not a vCenter Server")
            return -1
    elif args.operation == "postconfig":
        if aboutInfo.apiType == 'VirtualCenter':
            majorApiVersion = aboutInfo.apiVersion.split('.')[0]
            if int(majorApiVersion) < 6:
                print("This vCenter Server has version %s (lower than 6.0) "
                      "is not supported." % aboutInfo.apiVersion)
                return -1

            if args.clusterName is not None and \
                args.datacenterName is not None and \
                    args.esxIP is not None and \
                    args.esxPassword is not None:
                vcMos = vsanapiutils.GetVsanVcMos(si._stub, context=context)
                vvds = vcMos['vsan-vcsa-deployer-system']

                spec = vim.VsanVcPostDeployConfigSpec(
                    clusterName=args.clusterName,
                    dcName=args.datacenterName,
                    firstHost=vim.HostConnectSpec(
                        force=True,
                        hostName=args.esxIP,
                        userName="root",
                        password=args.esxPassword
                    ),
                    vsanDataEfficiencyConfig=vim.VsanDataEfficiencyConfig(
                        compressionEnabled=True,
                        dedupEnabled=True
                    )
                )
                print("\nPost-Configuring vCenter Server "
                      "and adding ESXi host ...")
                taskId = vvds.VsanPostConfigForVcsa(spec=spec)
                progress = vvds.VsanVcsaGetBootstrapProgress(taskId=[taskId])
                trackBootstrapProgress(vvds, progress, taskId)
            else:
                print("Incorrect input, postconfig requires --datacenterName, "
                      "--clusterName, --esxIP and --esxPassword")
                return -1
        else:
            print("postconfig operation requires that you connect "
                  "to the deployed vCenter Server, not ESXi host")
            return -1
    else:
        print("Invalid command-line options")
        return -1


# Start program
if __name__ == "__main__":
    main()
