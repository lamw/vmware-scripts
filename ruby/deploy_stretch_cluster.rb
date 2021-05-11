# William Lam
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware VSAN
# RVC script for automating the configuration of a VSAN Stretched Cluster
# Reference: http://www.williamlam.com/2015/10/automating-full-configuration-of-a-vsan-stretched-cluster-using-rvc.html

datacenter_name = "vGhetto-Datacenter"
vsan_cluster_name = "vGhetto-VSAN-Cluster"
vsan_witness_cluster_name = "vGhetto-VSAN-Witness-Cluster"
esxi_node1 = "vesxi60-4.primp-industries.com"
esxi_node2 = "vesxi60-5.primp-industries.com"
esxi_vsan_witness_node = "vesxi60-6.primp-industries.com"
esxi_username = "root"
esxi_password = "vmware123"
primary_fd = "Palo-Alto"
secondary_fd2 = "Santa-Barbara"

#### Do not edit beyond here ####

puts "Creating vSphere Datacenter: #{datacenter_name} ..."
rvc_exec("datacenter.create /localhost/#{datacenter_name}")

puts "Creating VSAN Cluster: #{vsan_cluster_name} ..."
rvc_exec("cluster.create /localhost/#{datacenter_name}/computers/#{vsan_cluster_name}")

puts "Adding #{esxi_node1} and #{esxi_node2} ESXi hosts to vSphere Cluster ..."
rvc_exec("cluster.add_host /localhost/#{datacenter_name}/computers/#{vsan_cluster_name} #{esxi_node1} #{esxi_node2} --username #{esxi_username} --password #{esxi_password} --insecure")

puts "Enabling VSAN on vSphere Cluster: #{vsan_cluster_name} ..."
rvc_exec("vsan.enable_vsan_on_cluster /localhost/#{datacenter_name}/computers/#{vsan_cluster_name}")

puts "Creating VSAN Witness Cluster: #{vsan_witness_cluster_name} ..."
rvc_exec("cluster.create /localhost/#{datacenter_name}/computers/#{vsan_witness_cluster_name}")

puts "Adding VSAN Witness ESXi host #{esxi_vsan_witness_node} to VSAN Witness Cluster: #{vsan_witness_cluster_name} ..."
rvc_exec("cluster.add_host /localhost/#{datacenter_name}/computers/#{vsan_witness_cluster_name} #{esxi_vsan_witness_node} --username #{esxi_username} --password #{esxi_password} --insecure")

puts "Creating Primary FD: #{primary_fd} and Secondary FD: #{secondary_fd2} on the 2-Node VSAN ESXi hosts ..."
rvc_exec("esxcli /localhost/#{datacenter_name}/computers/#{vsan_cluster_name}/hosts/#{esxi_node1} vsan faultdomain set -f #{primary_fd}")
rvc_exec("esxcli /localhost/#{datacenter_name}/computers/#{vsan_cluster_name}/hosts/#{esxi_node2} vsan faultdomain set -f #{secondary_fd2}")

puts "Configuring VSAN Stretched Cluster on VSAN Cluster: #{vsan_cluster_name} ..."
rvc_exec("vsan.stretchedcluster.config_witness /localhost/#{datacenter_name}/computers/#{vsan_cluster_name} /localhost/#{datacenter_name}/computers/#{vsan_witness_cluster_name}/hosts/#{esxi_vsan_witness_node} #{primary_fd}")
