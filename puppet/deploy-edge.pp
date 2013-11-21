transport { 'vcenter':
  username => 'root',
  password => 'vmware',
  server   => '172.30.0.135',
  options  => { 'insecure' => true },
}

transport { 'vshield':
  username => 'admin',
  password => 'default',
  server   => '172.30.0.136',
}

vshield_edge { '192.168.1.11:dmz':
  ensure             => present,
  datacenter_name    => 'ghetto-vdc',
  resource_pool_name => 'cluster-1',
  enable_aesni       => false,
  enable_fips        => false,
  enable_tcp_loose   => false,
  vse_log_level      => 'info',
  fqdn               => 'dmz.vm',
  vnics              => [
    { name          => 'uplink-test',
      portgroupName => 'VM Network',
      type          => "Uplink",
      isConnected   => "true",
      addressGroups => {
        "addressGroup" => {
          "primaryAddress" => "192.168.2.1",
          "subnetMask"     => "255.255.255.128",
        },
      },
    },
  ],
  transport  => Transport['vshield'],
}
