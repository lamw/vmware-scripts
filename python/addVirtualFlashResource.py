# William Lam
# www.virtuallyghetto.com
# Python script that calls vSphere MOB to add Virtual Flash Resource 

import sys,re,os,urllib,urllib2,base64

if len(sys.argv) == 1:
	print "\n\tUsage: " + str(sys.argv[0]) + " [VFFS-UUID]\n"
	sys.exit(1)
else:
	vffsUuid = str(sys.argv[1])
 
# mob url
url = "https://localhost/mob/?moid=ha-vflash-manager&method=configureVFlashResource"
 
# mob login credentials
username = "root"
password = "vmware123"
 
# Create global variables
global passman,authhandler,opener,req,page,page_content,nonce,headers,cookie,params,e_params
 
# Code to build opener with HTTP Basic Authentication
passman = urllib2.HTTPPasswordMgrWithDefaultRealm()
passman.add_password(None,url,username,password)
authhandler = urllib2.HTTPBasicAuthHandler(passman)
opener = urllib2.build_opener(authhandler)
urllib2.install_opener(opener)
 
### Code to capture required page data and cookie required for post back to meet CSRF requirements  ###
try:
	req = urllib2.Request(url)
	page = urllib2.urlopen(req)
	page_content= page.read()
except IOError, e:
	opener.close()
	sys.exit(1)
else:
	print "Successfully connected to vSphere MOB"
 
# regex to get the vmware-session-nonce value from the hidden form entry
reg = re.compile('name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"')
nonce = reg.search(page_content).group(1)
 
# get the page headers to capture the cookie
headers = page.info()
cookie = headers.get("Set-Cookie")

# Code to create HostVFlashManagerVFlashResourceConfigSpec
xml = '<spec xsi:type="HostVFlashManagerVFlashResourceConfigSpec"><vffsUuid>' + vffsUuid + '</vffsUuid></spec>'

try :
	params = {'vmware-session-nonce':nonce,'spec':xml}
	e_params = urllib.urlencode(params)
	req = urllib2.Request(url, e_params, headers={"Cookie":cookie})
	page = urllib2.urlopen(req).read()
except IOError, e:
	opener.close()
	sys.exit(1)
else:
	print "Successfully issued configureVFlashResource() with VFFS UUID " + vffsUuid + "\n"
