# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vCloud Networking & Security
# Description: Puppet Config for VCNS
# Reference: http://www.williamlam.com/2013/03/how-to-quickly-getting-started-with-new.html
transport { 'vshield':
  username => 'admin',
  password => 'default',
  server   => '172.30.0.136',
}

vshield_global_config { '172.30.0.136': 
  vc_info   => {
    ip_address => '172.30.0.135',
    user_name  => 'root',
    password   => 'vmware',
  },
  time_info => { 'ntp_server' => 'us.pool.ntp.org' },
  dns_info  => { 'primary_dns' => '172.30.0.100' },
  transport => Transport['vshield'],
}
