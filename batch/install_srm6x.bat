:: # Author: William Lam
:: # Website: www.virtuallyghetto
:: # Product: VMware Site Recovery Manager 6.0 / 6.1
:: # Description: Script to automate install SRM 6.0/6.1 w/embedded vPostgres DB
:: # Reference: http://www.virtuallyghetto.com/2015/11/automating-the-silent-installation-of-site-recovery-manager-6-06-1-wembedded-vpostgres-db.html

@ECHO off

::SRM 6.x execuable <---------REQUIRE EDITING BY USER
::set SRM_INSTALLER=C:\Users\Primp\Desktop\VMware-srm-6.1.0-3037005.exe
::set SRM_INSTALLER=C:\Users\Primp\Desktop\VMware-srm-6.0.0-2700459.exe

::SRM Logs (Requires the double escape path)
set SRM_INSTALL_LOG=C:\\srm_install.log

::Installation Directory - Default
set INSTALLDIR=C:\Program Files\VMware\VMware vCenter Site Recovery Manager

::vCenter Server Hostname <---------REQUIRE EDITING BY USER
set DR_TXT_VCHOSTNAME=vcenter60-4.primp-industries.com

:: vCenter Server Certificate Thumbprint <---------REQUIRE EDITING BY USER
set VC_CERTIFICATE_THUMBPRINT=BD:90:F4:0D:63:1D:F0:49:4A:D8:9B:F7:FF:17:D9:53:0F:E0:8A:54

:: PSC Server Hostname <---------REQUIRE EDITING BY USER
set PLATFORM_SERVICES_CONTROLLER_HOST=vcenter60-4.primp-industries.com

:: PSC Port 443 - Default
set PLATFORM_SERVICES_CONTROLLER_PORT=443

:: PSC Certificate Thumbprint <---------REQUIRE EDITING BY USER
set PLATFORM_SERVICES_CONTROLLER_THUMBPRINT=BD:90:F4:0D:63:1D:F0:49:4A:D8:9B:F7:FF:17:D9:53:0F:E0:8A:54

:: SSO Administrator Username <---------REQUIRE EDITING BY USER
set SSO_ADMIN_USER=Administrator@vghetto.local

:: SSO Administrator password <---------REQUIRE EDITING BY USER
set SSO_ADMIN_PASSWORD=VMware1!

::Local Site Name <---------REQUIRE EDITING BY USER
set DR_TXT_LSN=Palo-Alto

::Administrator Email <---------REQUIRE EDITING BY USER
set DR_TXT_ADMINEMAIL=admin@primp-industries.com

::Local Host address of SRM Server <---------REQUIRE EDITING BY USER
set DR_CB_HOSTNAME_IP=172.30.0.143

:: Default SRM Plugin Identifer - Default 1 (1 = Use default SRM PluginID 2 = Use Custom SRM PluginID)
set DR_RB_PLUGIN_ID=1

:: Plugin-ID
set DR_TXT_EXTKEY=com.vmware.vcDr

:: Organization
set DR_TXT_PLUGIN_COMPANY=VMware, Inc.

:: Description
set DR_TXT_PLUGIN_DESC=VMware vCenter Site Recovery Manager Extension

::Automatically generate a certificate - Default 1 (0 = Using existing PKCS#12 1 = Generate)
set DR_RB_CERTSEL=1

::Password for default certificate (Please change) <---------REQUIRE EDITING BY USER
set DR_TXT_CERTPWD=VMware1!

::Path to store default certificate
set DR_TXT_CERTFILE=C:\Program Files\VMware\VMware vCenter Site Recovery Manager\bin\%DR_CB_HOSTNAME_IP%.p12

::Certificate Organization <---------REQUIRE EDITING BY USER
set DR_TXT_CERTORG=primp-industries.com

::Certificate Organization Unit <---------REQUIRE EDITING BY USER
set DR_TXT_CERTORGUNIT=Skunkworks

::Used the embedded vPostgres database server - Default 1
set DR_USES_EMBEDDED_DB=1

::Embedded DB Data Source Name <---------REQUIRE EDITING BY USER
set DR_EMBEDDED_DB_DSN=srmdb

::Embedded DB User Name <---------REQUIRE EDITING BY USER
set DR_EMBEDDED_DB_USER=srm

::Embedded DB Password <---------REQUIRE EDITING BY USER
set DR_EMBEDDED_DB_PWD=VMware1!

::Embedded DB Port - Default 5678
set DR_EMBEDDED_DB_PORT=5678

::Embedded DB Connection Count - Defualt 5
set DR_TXT_CONNCNT=5

::Embedded DB Max Connections - Default 20
set DR_TXT_MAXCONNS=20

::Acount to run SRM Service <---------REQUIRE EDITING BY USER
set DR_SERVICE_ACCOUNT_NAME=PRIMP-IND\Administrator

:: ============ DO NOT EDIT BEYOND HERE ============ ::

:: Database type (Postgres, SQL Server or Oracle)
set DR_CB_DC=Postgres
:: Specifies whether vCenter Server is install locally (true or false)
set DR_TXT_VCLOCAL=false
:: Accepts VC Thumbprint
set DR_ACCEPT_THUMBPRINT=true
:: Specify whether to use or clear existing SRM database (0 = Use existing database 1 = Clear database)
set DR_RB_EXISTDBSEL=1

echo.
echo Start Time:
date/t
time /t
echo.
echo "Starting Site Recovery Manager installation ..."
"%SRM_INSTALLER%" /s /v"/l*vx %SRM_INSTALL_LOG% /qr AgreeToLicense=Yes INSTALLDIR=\"%INSTALLDIR%\" DR_TXT_VCHOSTNAME=%DR_TXT_VCHOSTNAME% VC_CERTIFICATE_THUMBPRINT=%VC_CERTIFICATE_THUMBPRINT% PLATFORM_SERVICES_CONTROLLER_HOST=%PLATFORM_SERVICES_CONTROLLER_HOST% PLATFORM_SERVICES_CONTROLLER_PORT=%PLATFORM_SERVICES_CONTROLLER_PORT% PLATFORM_SERVICES_CONTROLLER_THUMBPRINT=%PLATFORM_SERVICES_CONTROLLER_THUMBPRINT% SSO_ADMIN_USER=\"%SSO_ADMIN_USER%\" SSO_ADMIN_PASSWORD=\"%SSO_ADMIN_PASSWORD%\" DR_TXT_LSN=\"%DR_TXT_LSN%\" DR_TXT_ADMINEMAIL=\"%DR_TXT_ADMINEMAIL%\" DR_CB_HOSTNAME_IP=%DR_CB_HOSTNAME_IP% DR_RB_PLUGIN_ID=%DR_RB_PLUGIN_ID% DR_TXT_EXTKEY=\"%DR_TXT_EXTKEY%\" DR_TXT_PLUGIN_COMPANY=\"%DR_TXT_PLUGIN_COMPANY%\" DR_TXT_PLUGIN_DESC=\"%DR_TXT_PLUGIN_DESC%\" DR_RB_CERTSEL=%DR_RB_CERTSEL% DR_TXT_CERTPWD=\"%DR_TXT_CERTPWD%\" DR_TXT_CERTFILE=\"%DR_TXT_CERTFILE%\" DR_TXT_CERTORG=\"%DR_TXT_CERTORG%\" DR_TXT_CERTORGUNIT=\"%DR_TXT_CERTORGUNIT%\" DR_USES_EMBEDDED_DB=%DR_USES_EMBEDDED_DB% DR_EMBEDDED_DB_DSN=\"%DR_EMBEDDED_DB_DSN%\" DR_EMBEDDED_DB_USER=\"%DR_EMBEDDED_DB_USER%\" DR_EMBEDDED_DB_PWD=\"%DR_EMBEDDED_DB_PWD%\" DR_EMBEDDED_DB_PORT=%DR_EMBEDDED_DB_PORT% DR_TXT_CONNCNT=%DR_TXT_CONNCNT% DR_TXT_MAXCONNS=%DR_TXT_MAXCONNS% DR_SERVICE_ACCOUNT_NAME=\"%DR_SERVICE_ACCOUNT_NAME%\" DR_CB_DC=%DR_CB_DC% DR_TXT_VCLOCAL=%DR_TXT_VCLOCAL% DR_ACCEPT_THUMBPRINT=%DR_ACCEPT_THUMBPRINT% DR_RB_EXISTDBSEL=%DR_RB_EXISTDBSEL%"
echo.
echo End Time:
date/t
time /t
echo.
