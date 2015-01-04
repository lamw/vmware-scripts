# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCenter Server
# Description: Puppet Config for vCenter Server
# Reference: http://www.virtuallyghetto.com/2013/03/how-to-quickly-getting-started-with-new.html
transport { 'vcenter':
  username => 'root',
  password => 'vmware',
  server   => '172.30.0.135',
  options  => { 'insecure' => true },
}

vc_datacenter { 'ghetto-vdc':
  ensure    => present,
  path      => '/ghetto-vdc',
  transport => Transport['vcenter'],
}

vc_cluster { '/ghetto-vdc/cluster-1':
  ensure    => present,
  transport => Transport['vcenter'],
}

vc_cluster_drs { '/ghetto-vdc/cluster-1':
  require   => Vc_cluster['/ghetto-vdc/cluster-1'],
  before    => Anchor['/ghetto-vdc/cluster-1'],
  transport => Transport['vcenter'],
}

vc_cluster_evc { '/ghetto-vdc/cluster-1':
  require   => [
    Vc_cluster['/ghetto-vdc/cluster-1'],
    Vc_cluster_drs['/ghetto-vdc/cluster-1'],
  ],
  before    => Anchor['/ghetto-vdc/cluster-1'],
  transport => Transport['vcenter'],
}

anchor { '/ghetto-vdc/cluster-1': }

vcenter::host { '172.30.0.137':
  path      => '/ghetto-vdc/cluster-1',
  username  => 'root',
  password  => 'vmware123',
  dateTimeConfig => {
    'ntpConfig' => {
      'server' => 'us.ntp.pool.org',
    },
    'timeZone' => {
      'key' => 'UTC',
    },
  },
  transport => Transport['vcenter'],
}
