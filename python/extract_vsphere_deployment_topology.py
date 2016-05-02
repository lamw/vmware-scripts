#!/usr/bin/env python
# William Lam
# www.virtuallyghetto.com
# http://www.virtuallyghetto.com/2016/04/generating-vcenter-server-platform-services-controller-deployment-topology-diagrams.html

"""
Script to extract the deployment topology of your vSphere
enviornment (vCenter Server & PSC) and output as DOT Graph
"""

import atexit
import argparse
import getpass
import os
import socket
import subprocess
import sys
sys.path.extend(os.environ['VMWARE_PYTHON_PATH'].split(';'))

# Ugliness to handle Windows :X
if(sys.platform == "win32"):
   sys.path.append(os.path.join(os.environ['VMWARE_CIS_HOME'], 'vmafdd'))
   from cis.defaults import *
   import vmafd
   comp_path = get_component_home_dir(def_by_os('vmafd', 'vmafdd'))
   vmafd_cli_path = def_by_os(os.path.join(comp_path, 'bin/vmafd-cli'),os.path.join(comp_path, 'vmafd-cli.exe'))
   comp_path = get_component_home_dir(def_by_os('vmdir', 'vmdird'))
   vdcrepadmin_path = def_by_os(os.path.join(comp_path, 'bin/vdcrepadmin'),os.path.join(comp_path, 'vdcrepadmin.exe'))
   lstool_home_dir = r"C:\Program Files\VMware\vCenter Server\VMware Identity Services\lstool"
# Heart VCSA
else:
   vmafd_cli_path = "/usr/lib/vmware-vmafd/bin/vmafd-cli"
   vdcrepadmin_path = "/usr/lib/vmware-vmdir/bin/vdcrepadmin"
   lstool_home_dir = "/usr/lib/vmidentity/tools"

from pyVim import connect
from pyVmomi import vmodl
from urlparse import urlparse

# Global vars
VMTENV = os.environ.copy()
vc_username = ""
vc_username_wo_domain = ""
vc_domain = ""
vc_password = ""
vc_port = 443

def get_args():
    """Get command line args from the user.
    """
    parser = argparse.ArgumentParser(
        description='Standard Arguments for talking to vCenter')

    parser.add_argument('-o', '--port',
                        type=int,
                        default=443,
                        action='store',
                        help='Port to connect on')

    parser.add_argument('-u', '--user',
                        required=True,
                        action='store',
                        help='User name to use when connecting to host')

    parser.add_argument('-p', '--password',
                        required=False,
                        action='store',
                        help='Password to use when connecting to host')

    args = parser.parse_args()

    if not args.password:
        args.password = getpass.getpass(
            prompt='Enter SSO Admin password: ')

    return args

def execute(cmd, ofile=subprocess.PIPE, efile=subprocess.PIPE,
        env=os.environ):
    proc = subprocess.Popen(cmd, stdout=ofile, stderr=efile, env=env)
    out, err = proc.communicate()
    return (proc, out)

def build_vcenter_to_psc_relationship(vcenters):
    vcenter_to_psc_mapping = {}

    for vcenter in vcenters:
        try:
            service_instance = connect.SmartConnect(host=vcenter,
                                                user=vc_username,
                                                pwd=vc_password,
                                                port=vc_port)

            atexit.register(connect.Disconnect, service_instance)
            psc_settings = service_instance.content.setting.QueryOptions(name="config.vpxd.sso.admin.uri")
            for psc_setting in psc_settings:
               vcenter_to_psc_mapping[vcenter] = urlparse(psc_setting.value).hostname

    	except vmodl.MethodFault as error:
        	print "Caught vmodl fault : " + error.msg
        	return -1

    return vcenter_to_psc_mapping

def build_psc_to_site_relationship():
    psc_to_site = {}
    psc_servers = {}
    sso_sites = {}

    (proc, out) = execute([vdcrepadmin_path, '-f', 'showservers', '-h', 'localhost', '-u', vc_username_wo_domain, '-w', vc_password],env=VMTENV)
    results = out.strip().split('\n')
    for line in results:
        delim = line.split(',')
        psc_server = delim[0][3:]
        sso_site = delim[2][3:]
        psc_to_site[psc_server] = sso_site
        psc_servers[psc_server] = ""
        sso_sites[sso_site] = ""

    return psc_to_site,psc_servers,sso_sites

def build_psc_replication_relationship(pscs):
    psc_replication_mapping = {}

    for psc in pscs:
    	(proc, out) = execute([vdcrepadmin_path, '-f', 'showpartners', '-h', psc, '-u', vc_username_wo_domain, '-w', vc_password],env=VMTENV)
        results = out.strip().split('\n')
        for psc_replication_partner in results:
            key = psc
            value = psc_replication_partner[7:]
            # Ignore duplicate replication agreements
            if(psc_replication_mapping.has_key(value) == False or psc_replication_mapping[value] != key):
                psc_replication_mapping[psc] = psc_replication_partner[7:]

    return psc_replication_mapping

def find_all_vcenter_servers():
    vcenter_servers = {}

    psc_hostname = socket.getfqdn()
    (proc, out) = lstool_communicate(["list", "--product", "com.vmware.cis", "--type", "vcenterserver", "--ep-type", "com.vmware.vim.extension", "--url", "https://" + psc_hostname + ":7444/lookupservice/sdk"], env=VMTENV)
    results = out.strip().split('\n')
    for r in results:
       line = r.strip()
       if("com.vmware.vim.vcenter.instanceName:" in line):
          var,vc = line.split(": ")
          vcenter_servers[vc] = ""

    return vcenter_servers

def build_dot_graph(sso_sites,psc_servers,vcenter_servers,psc_to_site,psc_replication_mapping,vcenter_to_psc_mapping):
    # Extract SSO Domain Name
    (proc, out) = execute([vmafd_cli_path, 'get-domain-name', '--server-name', 'localhost'],env=VMTENV)
    sso_domain_name = out.strip()

    print "graph vghetto_vsphere_topology_extraction {"
    print "   graph [fontsize = 20,label = \"\\nSSO Domain: " + sso_domain_name + "\"];"

    sso_sites_keylist = sso_sites.keys()
    sso_sites_keylist.sort()
    psc_to_psc_between_sites = {}
    embedded_vcs = {}
    count = 0

    for sso_site in sso_sites_keylist:
        print "   subgraph cluster_" + str(count) + " {"
        print "      style=filled;"
        print "      node [style=filled];"

        seen_psc = {}
        node_printed = {}
        psc_to_sites_keylist = psc_to_site.keys()
        psc_to_sites_keylist.sort()

        for source in psc_to_sites_keylist:
            if(psc_to_site[source] == sso_site):
                if(vcenter_servers.has_key(source)) == False:
                   seen_psc[source] = ""
                vcenter_to_psc_mapping_keylist = vcenter_to_psc_mapping.keys()
                vcenter_to_psc_mapping_keylist.sort()
                # Handle VC to PSC Association
                for target in vcenter_to_psc_mapping_keylist:
                    if(vcenter_to_psc_mapping[target] == source):
                        print "      \"" + target + "\" -- \"" + source + "\""
                        node_printed[target] = "1"
                    # Handle Embedded <-> PSC repplication
                    if(source == target):
                       embedded_vcs[source] = ""
                       node_printed[source] = "1"
                # PSC to PSC Association
                if(psc_replication_mapping.has_key(source)):
                    # If PSC Replication is between sites, we need to print this outside of the subgraph
                    psc_left = psc_to_site[source]
                    if(psc_replication_mapping.has_key(source)):
                       if(psc_to_site.has_key(psc_replication_mapping[source])):
                          psc_right = psc_to_site[psc_replication_mapping[source]]
                       else:
                          psc2psc_string = "      \"" + source + "\" -- \"" + source + "\""
                          embedded_vcs[source] = ""
                          node_printed[source] = "1"
                          print psc2psc_string
                          break
                    else:
                       psc2psc_string = "      \"" + source + "\" -- \"" + source + "\""
                       embedded_vcs[source] = ""
                       node_printed[source] = "1"
                       print psc2psc_string
                       break
                    # If the Site that two PSC's do not match, it means its cross site replication
                    if(psc_left != psc_right):
                        psc2psc_string = "   \"" + source + "\" -- \"" + psc_replication_mapping[source] + "\""
                        psc_to_psc_between_sites[psc2psc_string] = ""
                        node_printed[source] = "1"
                        node_printed[psc_replication_mapping[source]] = "1"
                    else:
                        psc2psc_string = "      \"" + source + "\" -- \"" + psc_replication_mapping[source] + "\""
                        print psc2psc_string
                        node_printed[source] = "1"
                        node_printed[psc_replication_mapping[source]] = "1"

        for i in seen_psc.keys():
           if(node_printed.has_key(i) == False):
              print "      \"" + i + "\";"
        seen_psc = {}
        node_printed = {}
        print "      label = \"Site: " + sso_site + "\";"
        print "    }"
        count +=1

    # Print PSC replication between sites
    for i in psc_to_psc_between_sites.keys():
       print i

    # Add some colors to VC / PSC Nodes
    for j in vcenter_servers.keys():
       print "   \"" + j + "\" [color=\"0.578 0.289 1.000\"]"
    for k in psc_servers.keys():
       print "   \"" + k + "\" [color=\"0.355 0.563 1.000\"];"
    for l in embedded_vcs.keys():
       print "   \"" + l + "\" [color=\"darkorange1\"];"

    print "}"

# Borrowed from lstool.py
# since its pita to run directly
# using subprocess
def _get_java_security_properties():
   return os.path.join(os.environ['VMWARE_CFG_DIR'],
                       "java",
                       "vmware-override-java.security")

def _get_classpath():
   ls_libdir = os.path.join(lstool_home_dir, "lib")
   return os.path.join(ls_libdir, "lookup-client.jar") + os.pathsep + os.path.join(ls_libdir, "*") + os.pathsep + ls_libdir

def _get_java():
   java_home = ""
   if os.environ.has_key('VMWARE_JAVA_HOME'):
      java_home = os.environ['VMWARE_JAVA_HOME']
   elif os.environ.has_key('JAVA_HOME'):
      java_home = os.environ['JAVA_HOME']
   else:
      raise Exception("ERROR: VMWARE_JAVA_HOME or JAVA_HOME not set in environment." +
                      " Please set to location of Java runtime and retry.")

   if(os_platform == "vc-windows"):
      ext = ".exe"
   else:
      ext = ""
   return "%s/bin/java%s" % (java_home, ext)

def lstool_communicate(argv, ofile=subprocess.PIPE, efile=subprocess.PIPE,
        env=os.environ):
   """
   Lookup service client tool
   """
   cmd = [_get_java(),
          "-Djava.security.properties=%s" % _get_java_security_properties(),
          "-cp",
          _get_classpath(),
          "-Dlog4j.configuration=tool-log4j.properties"]
   cmd.append("com.vmware.vim.lookup.client.tool.LsTool")
   cmd += argv
   proc = subprocess.Popen(cmd, stdout=ofile, stderr=efile, env=env)
   out, err = proc.communicate()
   return (proc, out)

def main():
    """
    Script to extract the deployment topology of your vSphere enviornment (vCenter Server & PSC) and output as DOT Graph
    """

    global os_platform, vc_username,vc_password,vc_username_wo_domain,vc_domain,vc_port

    # Figure out if we're on Windows VC or VCSA
    if(sys.platform == "win32"):
	os_platform = "vc-windows"
    else:
	os_platform = "vcsa"

    args = get_args()

    vc_username = args.user
    vc_password = args.password
    vc_username_wo_domain,vc_domain = vc_username.split("@")
    vc_domain = vc_domain.replace(".local", "")
    vc_port = int(args.port)

    # Using vdcrepadmin (https://kb.vmware.com/kb/2127057) to find extract PSC to SSO Site associations
    psc_to_site,psc_servers,sso_sites = build_psc_to_site_relationship()

    # Using vdcrepadmin (https://kb.vmware.com/kb/2127057) to find extract PSC replication information
    psc_replication_mapping = build_psc_replication_relationship(psc_servers)

    # Using lstool.py to extract all vCenter Servers within SSO Domain
    # (http://www.virtuallyghetto.com/2015/04/vcenter-server-6-0-tidbits-part-2-what-is-my-sso-domain-name-site-name.html)
    # (http://www.virtuallyghetto.com/2015/04/vcenter-server-6-0-tidbits-part-4-finding-all-deployed-vcenter-servers.html)
    vcenter_servers = find_all_vcenter_servers()

    # Using pyvmomi to connect to vSphere API to extract PSC Server used by given vCenter Server
    vcenter_to_psc_mapping = build_vcenter_to_psc_relationship(vcenter_servers)

    # Building DOT Graph of VC/PSC deployment topology (ugly code right now, but limited due to excuting env)
    build_dot_graph(sso_sites,psc_servers,vcenter_servers,psc_to_site,psc_replication_mapping,vcenter_to_psc_mapping)

    return 0

# Start program
if __name__ == "__main__":
    main()
