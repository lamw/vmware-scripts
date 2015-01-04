# William Lam
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCloud Director
# Description: Exploring the vCloud Director API using Ruby
# Reference: http://www.virtuallyghetto.com/2013/02/exploring-vcloud-api-using-ruby.html 

require 'httparty'
require 'yaml'
require 'xml-fu'
require 'pp'

def usage
	puts "\nUsage: #{$0} operation [vapp-name] [snap-name]\n"
	puts "\n\toperation: list|get|poweron|poweroff|shutdown|reset|suspend|createsnapshot|removesnapshot"
	puts "\n\te.g. #{$0} list"
	puts "\te.g. #{$0} get MyvApp"
	puts "\te.g. #{$0} poweron MyvApp"
	puts "\te.g. #{$0} createsnapshot MyvApp snap-1"
	puts "\n"
end

class Vcd
	include HTTParty
	format :xml

	def initialize(file_path="config-vcd.yml")
		raise "no file #{file_path}" unless File.exists? file_path
		configuration = YAML.load_file(file_path)	
		self.class.basic_auth configuration[:username], configuration[:password]
		self.class.base_uri configuration[:site]
		self.class.default_options[:headers] = {"Accept" => "application/*+xml;version=5.1"}
	end

	def login
		puts "Logging in ...\n\n"
		response = self.class.post('/api/sessions')
		#setting global cookie var to be used later on
		@cookie = response.headers['set-cookie']
		self.class.default_options[:headers] = {"Accept" => "application/*+xml;version=5.1", "Cookie" => @cookie}
	end

	def logout
		puts "Logging out ...\n\n"
		self.class.delete('/api/session')
	end

	def links
		response = self.class.get('/api/session')
		response['Session']['Link'].each do |link|
			puts link['href']
		end
	end

	def listVapps
		response = self.class.get("/api/query/?type=adminVApp")
		response['QueryResultRecords']['AdminVAppRecord'].each do |vapp|
			printVapp(vapp)
		end
	end

	def getVapp(name)
		response = self.class.get("/api/query/?type=adminVApp&filter=name==#{name}")
		vapp = response['QueryResultRecords']['AdminVAppRecord']

		if vapp['href']
			return vapp
		else
			puts "Unable to find vApp #{name}"
		end
	end

	def printVapp(vapp)
		puts "vApp: #{vapp['name']}"
		puts "Owner: #{vapp['ownerName']}"
		puts "OrgVDC: #{vapp['vdcName']}"
		puts "Status: #{vapp['status']}"
		puts "NumVMs: #{vapp['numberOfVMs']}"
		puts "CpuAllocated: #{vapp['cpuAllocationMhz']} Mhz"
		puts "MemAllocated: #{vapp['memoryAllocationMB']} MB"
		puts "StorageAllocated: #{vapp['storageKB']} KB"
		puts "\n"
	end

	def getVappHref(vapp)
		return vapp['href']
	end
	
	def powerOp(vappHref,opType)
		case opType
		when "poweron"
			response = self.class.post("#{vappHref}/power/action/powerOn")	
		when "poweroff"
			response = self.class.post("#{vappHref}/power/action/powerOff")
		when "shutdown"
			response = self.class.post("#{vappHref}/power/action/shutdown")
		when "suspend"
			response = self.class.post("#{vappHref}/power/action/suspend")
		when "reset"
			response = self.class.post("#{vappHref}/power/action/reset")
		end
		taskHref = response['Task']['href']
		getTaskStatus(taskHref)
	end

	def snapshotVapp(vappHref,snapName)
		snapshotParam = XmlFu.xml("vcloud:CreateSnapshotParams" => { 
			"@xmlns:vcloud" => "http://www.vmware.com/vcloud/v1.5",
			"@memory" => "true", 
			"@name" => snapName,
			"@quiesce" => "true",
			"vcloud:Description" => "test"
		})
		self.class.default_options[:headers] = {"Accept" => "application/*+xml;version=5.1", "Cookie" => @cookie, "Content-Type" => "application/vnd.vmware.vcloud.createSnapshotParams+xml"}
		response = self.class.post("#{vappHref}/action/createSnapshot", :body => snapshotParam)
		taskHref = response['Task']['href']
		getTaskStatus(taskHref)
	end

	def removeSnapshot(vappHref)
		response = self.class.post("#{vappHref}/action/removeAllSnapshots")
		taskHref = response['Task']['href']
		getTaskStatus(taskHref)
	end

	def getTaskStatus(taskHref)
		continue = 1	
		while continue == 1
			response = self.class.get(taskHref)
			status = response['Task']['status']
			if status == "success"
				print "Successfully completed operation!\n\n"
				continue = 0
			elsif status == "error" || status == "aborted" || status == "cancelled"
				puts "Error Details: #{response['Task']['Details']}\n\n"
				break 
			end
			sleep 5
			response = self.class.get(taskHref)		
		end
	end
end

operation = ARGV[0]
vappName = ARGV[1]
snapName = ARGV[2]

if operation
	vcd = Vcd.new()
	vcd.login
	#vcd.links

	case operation.chomp
	when "list"
		vcd.listVapps
	when "get"
		if vappName
			puts "Retrieving vApp #{vappName} ..."
			vcd.printVapp(vcd.getVapp(vappName))
		else
			puts "Error: Please provide vApp name!\n\n"
		end
	when "poweron"
		if vappName
			puts "Powering on vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.powerOp(vappHref,'poweron')
		else
			puts "Error: Please provide vApp name!\n\n"
		end
	when "resume"
		if vappName
			puts "Resuming vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.powerOp(vappHref,'poweron')
		else
			puts "Error: Please provide vApp name!\n\n"
		end
	when "poweroff"
		if vappName
			puts "Powering off vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.powerOp(vappHref,'poweroff')
		else
			puts "Error: Please provide vApp name!\n\n"
		end
	when "shutdown"
		if vappName
			puts "Shuting down vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.powerOp(vappHref,'shutdown')
		else
			puts "Error: Please provide vApp name!\n\n"
		end
	when "reset"
		if vappName
			puts "Resetting vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.powerOp(vappHref,'reset')
		else
			puts "Error: Please provide vApp name!\n\n"
		end
	when "suspend"
		if vappName
			puts "Suspending vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.powerOp(vappHref,'suspend')
		else
			puts "Error: Please provide vApp name!\n\n"
		end
	when "createsnapshot"
		if snapName && vappName
			puts "Creating snapshot #{snapName} for vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.snapshotVapp(vappHref,snapName)
		else 
			puts "Error: Please provide vApp & Snapshot name!\n\n"
		end
	when "removesnapshot"
		if vappName
			puts "Removing snapshot for vApp #{vappName} ..."
			vappHref = vcd.getVappHref(vcd.getVapp(vappName))
			vcd.removeSnapshot(vappHref)
		else
			puts "Error: Please provide vApp name!\n\n"
		end		
	else
		puts "Incorrect Operation!\n"
		usage() 
	end
	vcd.logout()
else
	usage()
end
