# William Lam
# www.virtuallyghetto.com
# Exploring the vCNS API using Ruby

require 'httparty'
require 'yaml'
require 'pp'
require 'libxml'

class Vcns
	include HTTParty
	format :xml

	def initialize(file_path="config-vcns.yml")
		raise "no file #{file_path}" unless File.exists? file_path
		configuration = YAML.load_file(file_path)	
		self.class.basic_auth configuration[:username], configuration[:password]
		self.class.base_uri configuration[:site]
		self.class.default_options[:headers] = {"Content-Type" => "application/xml"}
	end

	def getVcnsConfig
		response = self.class.get('/api/2.0/global/config')
		vcInfo = response['vsmGlobalConfig']['vcInfo']
		ssoInfo = response['vsmGlobalConfig']['ssoInfo']
		dnsInfo = response['vsmGlobalConfig']['dnsInfo']
		timeInfo = response['vsmGlobalConfig']['timeInfo']

		puts "\nvCNS Configuration"
		puts "\tvCenter: #{vcInfo['ipAddress']}"
		puts "\tUsername: #{vcInfo['userName']}"
		puts "\tSSOLookupServiceURL: #{ssoInfo['lookupServiceUrl']}"
		puts "\tPrimaryDNS: #{dnsInfo['primaryDns']}"
		puts "\tSecondaryDNS: #{dnsInfo['secondaryDns']}"
		puts "\tTertiaryDNS: #{dnsInfo['tertiaryDns']}"
		puts "\tNTPServer: #{timeInfo['ntpServer']}"
		puts "\tClock: #{timeInfo['clock']}"
		puts "\tTimeZone: #{timeInfo['zone']}"
	end

	def listLinks
		response = self.class.get('/api/versions')
		links = response['versions']['version']
		[links].flatten.each do |link|
			puts "\nAPI Version: #{link['value']}"
			printLinks(link['module'])
		end
	end

	def printLinks(link)
		[link].flatten.each do |l|
			puts "\t#{l['name']} = #{l['baseUri']}" 
		end
	end

	def listEdges
		response = self.class.get('/api/3.0/edges')
		edges = response['pagedEdgeList']['edgePage']['edgeSummary']
		puts "\nvCNS Edges Summary"
		[edges].flatten.each do |edge|
			printEdges(edge)
		end
	end

	def printEdges(edge)
		@vcnsEdges = Array.new()
		@vcnsEdges.push(edge['id'])
		puts "\tName: #{edge['name']}"
		puts "\tId: #{edge['id']}"
		puts "\tState: #{edge['state']}"
		puts "\tSize: #{edge['appliancesSummary']['applianceSize']}"
		puts "\tNumNics: #{edge['numberOfConnectedVnics']}"
		puts "\tNumVMs: #{edge['appliancesSummary']['numberOfDeployedVms']}"
		puts "\tEdgeName: #{edge['appliancesSummary']['vmNameOfActiveVse']}"
		puts "\tDatacenter: #{edge['datacenterName']}"
		puts "\tESXi: #{edge['appliancesSummary']['hostNameOfActiveVse']}"
		puts "\tResourcePool: #{edge['appliancesSummary']['resourcePoolNameOfActiveVse']}"
		puts "\tDatastore: #{edge['appliancesSummary']['dataStoreNameOfActiveVse']}"
		puts "\n"
	end

	def getEdgeDetails
		puts "vCNS Edges Details"
		@vcnsEdges.each do |edge|
			response = self.class.get("/api/3.0/edges/#{edge}")
			edgeDetails = response['edge']
			[edgeDetails].flatten.each do |edgeDetail|
				puts "\tName: #{edgeDetail['name']}"
				puts "\tId: #{edgeDetail['id']}"
				puts "\tCLIEnabled: #{edgeDetail['cliSettings']['remoteAccess']}"
				puts "\tCLIUsername: #{edgeDetail['cliSettings']['userName']}"
		
				ha = edgeDetail['features']['highAvailability']
				syslog = edgeDetail['features']['syslog']
				firewall = edgeDetail['features']['firewall']
				dns = edgeDetail['features']['dns']
				ssl = edgeDetail['features']['sslvpnConfig']
				ipsec = edgeDetail['features']['ipsec']
				dhcp = edgeDetail['features']['dhcp']
				nat = edgeDetail['features']['nat']
				loadbalancer = edgeDetail['features']['loadBalancer']
	
				printEdgeSyslog(syslog)
				printEdgeHA(ha)
				printEdgeFirewall(firewall)
				printEdgeDns(dns)
				printEdgeSsl(ssl)
				printEdgeIpsec(ipsec)
				printEdgeDhcp(dhcp)
				printEdgeNat(nat)
				printEdgeLB(loadbalancer)
			end
		end
	end

	def printEdgeSyslog(syslog)
		puts "\nSyslog Enabled: #{syslog['enabled']}"
	end

	def printEdgeHA(ha)
		puts "\nHA Enabled: #{ha['enabled']}"
		puts "\tLoggingEnabled: #{ha['logging']['enable']}"
		puts "\tLoggingLevel: #{ha['logging']['logLevel']}"
	end

	def printEdgeFirewall(firewall)
		puts "\nFirewall Enabled: #{firewall['enabled']}"
		puts "\tLoggingEnabled: #{firewall['defaultPolicy']['loggingEnabled']}"
		rules = firewall['firewallRules']['firewallRule']
		[rules].flatten.each do |rule|
			puts "\tName: #{rule['name']}"
			puts "\tId: #{rule['id']}"
			puts "\tEnabled: #{rule['enabled']}"
			puts "\tRuleType: #{rule['ruleType']}"
			puts "\tAction: #{rule['action']}"
			puts "\tLoggingEnabled: #{rule['loggingEnabled']}"
			puts "\n"
		end
	end

	def printEdgeDns(dns)
		puts "\nDNS Enabled: #{dns['enabled']}"
		puts "\tLoggingEnabled: #{dns['logging']['enable']}"
		puts "\tLoggingLevel: #{dns['logging']['logLevel']}"
	end

	def printEdgeSsl(ssl)
		puts "\nSSL Enabled: #{ssl['enabled']}"
		puts "\tLoggingEnabled: #{ssl['logging']['enable']}"
		puts "\tLoggingLevel: #{ssl['logging']['logLevel']}" 
	end

	def printEdgeIpsec(ipsec)
		puts "\nIPSec Enabled: #{ipsec['enabled']}"
		puts "\tLoggingEnabled: #{ipsec['logging']['enable']}"
		puts "\tLoggingLevel: #{ipsec['logging']['logLevel']}"
	end

	def printEdgeDhcp(dhcp)
		puts "\nDHCP Enabled: #{dhcp['enabled']}"
		puts "\tLoggingEnabled: #{dhcp['logging']['enable']}"
		puts "\tLoggingLevel: #{dhcp['logging']['logLevel']}"
	end

	def printEdgeNat(nat)
		puts "\nNAT Enabled: #{nat['enabled']}"
	end

	def printEdgeLB(loadbalancer)
		puts "\nLoadBalancer Enabled: #{loadbalancer['enabled']}"
		puts "\tL4-Mode Enabled: #{loadbalancer['accelerationEnabled']}"
	end
end

vcns = Vcns.new()
vcns.getVcnsConfig()
#vcns.listLinks
vcns.listEdges()
vcns.getEdgeDetails()
