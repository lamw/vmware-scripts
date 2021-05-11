# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vSphere
# Description: Puppet Config for vCenter Server
# Reference: http://www.williamlam.com/2013/03/how-to-quickly-getting-started-with-new.html
node 'corpse.primp-industries.com' {
  include 'vcenter::package'
}
