#!/usr/bin/python
# Alan Castonguay
# Python script to configure power management policy on ESXi host

import sys
from pyVim.connect import Connect

def main(argv):
   si = Connect()
   content = si.RetrieveContent()
   rootFolder = content.GetRootFolder()
   dataCenter = rootFolder.GetChildEntity()[0]
   hostFolder = dataCenter.hostFolder
   host = hostFolder.childEntity[0]
   hostSystem = host.host[0]
   configManager = hostSystem.GetConfigManager()
   powerSystem = configManager.GetPowerSystem()
   hostConfigInfo = hostSystem.config
   
   if len(argv)>0:
      for policy in hostConfigInfo.powerSystemCapability.availablePolicy:
         if policy.shortName == argv[0]:
             r=powerSystem.ConfigurePowerPolicy(policy.key)
             if r == None:
                return 0
             print r
             return 1
      print 'Policy shortName "{0}" not found.'.format(argv[0])
      return 1
   
   else:
      print "{0:4} {1:10} {2:10} {3}".format("key", "current", "shortName","name") 
      for policy in hostConfigInfo.powerSystemCapability.availablePolicy:
         print "{0!s:4} {1!r:10} {2:10} {3}".format(policy.key, policy.name == hostConfigInfo.powerSystemInfo.currentPolicy.name, policy.shortName, policy.name)     
      return 0	

# Start program
if __name__ == "__main__":
    exit(main(sys.argv[1:]))
