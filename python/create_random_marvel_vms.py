
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vSphere
# Description: vSphere SDK for Python (pyvmomi) program for creating tiny VMs (1vCPU/128MB) with random names using the Marvel Comics API
# Reference: http://www.williamlam.com/2014/02/having-some-fun-with-marvel-comics-api.html

"""
vSphere SDK for Python program for creating tiny VMs (1vCPU/128MB) with random names using the Marvel Commics API
"""

from optparse import OptionParser, make_option
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim, VmomiSupport
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from pyVmomi import vmodl
from pyVmomi import vim
from pprint import pprint

import requests
import json
import time
import hashlib
import random
import argparse
import atexit
import sys
import string
import ssl

# Marvel API keys
marvel_public_key = ''
marvel_private_key = ''

def GetArgs():
    """
    Supports the command-line arguments listed below.
    """
    parser = argparse.ArgumentParser(
        description='Process args for retrieving all the Virtual Machines')
    parser.add_argument('-s', '--host', required=True,
                        action='store', help='Remote host to connect to')
    parser.add_argument('-o', '--port', type=int, default=443,
                        action='store', help='Port to connect on')
    parser.add_argument('-u', '--user', required=True, action='store',
                        help='User name to use when connecting to host')
    parser.add_argument('-p', '--password', required=True,
                        action='store', help='Password to use when connecting to host')
    parser.add_argument('-c', '--count', required=True,
                        action='store', help='Number of VMs to create')
    parser.add_argument('-d', '--datastore', required=True,
                        action='store', help='Name of Datastore to create VM in')
    parser.add_argument('-e', '--datacenter', required=True,
                        action='store', help='Name of Datastore to create VM in')
    parser.add_argument('-f', '--opid', default='create-marvel-vm',
                        action='store', help='Name of Datastore to create VM in')
    args = parser.parse_args()
    return args

def find_datacenter(service_instance, datacenter_name):
    content = service_instance.RetrieveContent()

    # Traverse the inventory hierarchy starting from the root folder
    for child_entity in content.rootFolder.childEntity:
        if isinstance(child_entity, vim.Datacenter):
            if child_entity.name == datacenter_name:
                return child_entity

    # Datacenter not found
    return None

def getMarvelCharacters(number_of_characters):
    timestamp = str(int(time.time()))
    # hash is required as part of request which is md5(timestamp + private + public key)
    hash_value = hashlib.md5(
        (timestamp + marvel_private_key + marvel_public_key).encode('utf-8')).hexdigest()

    characters = []
    for x in range(number_of_characters):
        # randomly select one of the 1402 Marvel character
        offset = random.randrange(1, 1402)
        limit = '1'

        # GET /v1/public/characters
        url = 'http://gateway.marvel.com:80/v1/public/characters?limit=' + limit + '&offset=' + \
            str(offset) + '&apikey=' + marvel_public_key + \
            '&ts=' + timestamp + '&hash=' + hash_value
        headers = {'content-type': 'application/json'}
        request = requests.get(url, headers=headers)
        data = json.loads(request.content)
        # retrieve character name & replace spaces with underscore so we don't have stupid spaces in our VM names
        character = 'marvelvm-' + \
            data['data']['results'][0]['name'].strip().replace(' ', '_')
        characters.append(character.lower())
    return characters

def CreateDummyVM(name, si, vmFolder, rp, datastore):
    datastorePath = f"[{datastore}]"

    # bare minimum VM shell, no disks. Feel free to edit
    file = vim.vm.FileInfo(logDirectory=None, snapshotDirectory=None,
                suspendDirectory=None, vmPathName=datastorePath)
    config = vim.vm.ConfigSpec(
        name=name, memoryMB=128, numCPUs=1, files=file, guestId='dosGuest', version='vmx-13')

    print("Creating VM " + name + " ...")
    task = vmFolder.CreateVM_Task(config=config, pool=rp)
    WaitForTasks([task], si)

# borrowed from poweronvm.py sample
def WaitForTasks(tasks, si):
    """
    Given the service instance si and tasks, it returns after all the
    tasks are complete
    """

    pc = si.content.propertyCollector

    taskList = [str(task) for task in tasks]

    # Create filter
    objSpecs = [vmodl.query.PropertyCollector.ObjectSpec(obj=task)
                for task in tasks]
    propSpec = vmodl.query.PropertyCollector.PropertySpec(type=vim.Task, pathSet=[], all=True)
    filterSpec = vmodl.query.PropertyCollector.FilterSpec()
    filterSpec.objectSet = objSpecs
    filterSpec.propSet = [propSpec]
    filter = pc.CreateFilter(filterSpec, True)

    try:
        version, state = None, None

        # Loop looking for updates till the state moves to a completed state.
        while len(taskList):
            update = pc.WaitForUpdates(version)
            for filterSet in update.filterSet:
                for objSet in filterSet.objectSet:
                    task = objSet.obj
                    for change in objSet.changeSet:
                        if change.name == 'info':
                            state = change.val.state
                        elif change.name == 'info.state':
                            state = change.val
                        else:
                            continue

                        if not str(task) in taskList:
                            continue

                        if state == vim.TaskInfo.State.success:
                            # Remove task from taskList
                            taskList.remove(str(task))
                        elif state == vim.TaskInfo.State.error:
                            raise task.info.error
            # Move to next version
            version = update.version
    finally:
        if filter:
            filter.Destroy()

def main():
    """
    Simple command-line program for creating Dummy VM based on Marvel character names
    """

    args = GetArgs()

    # Set custom OpID for this connection
    reqCtx = VmomiSupport.GetRequestContext()
    reqCtx["operationID"] = args.opid

    try:
        context = None
        try:
            if sys.version_info[:3] > (2, 7, 8):
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE

            # Disabling the annoying InsecureRequestWarning message
            requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

            si = SmartConnect(host=args.host,
                            user=args.user,
                            pwd=args.password,
                            port=int(args.port),
                            sslContext=context)
        except IOError as e:
            pass
        if not si:
            print(
                "Could not connect to the specified host using specified username and password")
            return -1

        atexit.register(Disconnect, si)

        content = si.RetrieveContent()
        dc = find_datacenter(si, args.datacenter)
        vmFolder = dc.vmFolder
        hosts = dc.hostFolder.childEntity
        rp = hosts[0].resourcePool

        # Ensure user sets up Marvel API keys
        if marvel_public_key == '' or marvel_private_key == '':
            print("\nPlease configure your Marvel Public/Private API Key by setting marvel_public_key and marvel_private_key variable\n")
            print("Generating random VM name for now ...")
            characters = ['randomvm-' + ''.join(random.choice(string.ascii_letters)
                                                for _ in range(10)) for _ in range(int(args.count))]
        else:
            print("Connecting to Marvel API and retrieving " + args.count + " random character(s) ...")
            characters = getMarvelCharacters(int(args.count))

        for name in characters:
            CreateDummyVM(name, si, vmFolder, rp, args.datastore)

    except vmodl.MethodFault as e:
        print("Caught vmodl fault : " + e.msg)
        return -1
    except Exception as e:
        print("Caught exception : " + str(e))
        return -1

    return 0

# Start program
if __name__ == "__main__":
    main()
