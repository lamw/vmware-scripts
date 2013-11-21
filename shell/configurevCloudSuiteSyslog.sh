#1/bin/bash
# William Lam
# www.virtuallyghetto.com

UNIQUE_CONFIGURE_STRING="# Configured using vCloud Suite Syslog Configuration Script by William Lam"
SYSLOG_NG_CONF=/etc/syslog-ng/syslog-ng.conf
ALREADY_CONFIGURE_STRING="This host has already been configured before, please take a look at ${SYSLOG_NG_CONF}"

usage() {
	echo -e "\nvCloud Suite Syslog Configuration Script by William Lam (www.virtuallyghetto.com)"
	echo -e "\n\t$0 [VMWARE-SOLUTION] [VCENTER-LOG-INSIGHT]\n"
	echo -e "\tVMware Solutions"
	echo -e "\t\tvin"
	echo -e "\t\tvcops-ui"
	echo -e "\t\tvcops-ana"
	echo -e "\t\tvco"
	echo -e "\t\tvcsa"
	echo -e "\t\tvcc-server"
	echo -e "\t\tvcc-node"
	echo -e "\t\tvma"
	echo -e "\t\tvdp"
	echo -e "\t\tvr"
	echo -e "\t\tvcd"
	echo -e "\n"
	exit 1
}

configureVIN() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VIN__

${UNIQUE_CONFIGURE_STRING}
source vin {
       file("/var/log/vadm/system.log" log_prefix("vin: ") follow_freq(1) flags(no-parse));
       file("/var/log/vadm/engine.log" log_prefix("vin: ") follow_freq(1) flags(no-parse));
       file("/var/log/vadm/activecollector.log" log_prefix("vin: ") follow_freq(1) flags(no-parse));
       file("/var/log/vadm/dbconfig.log" log_prefix("vin: ") follow_freq(1) flags(no-parse));
       file("/var/log/vadm/db/postgresql.log" log_prefix("vin: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vin);
        destination(remote_syslog);
};
__VIN__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVCOPSUI() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VCOPSUI__

${UNIQUE_CONFIGURE_STRING}
source vcops-ui {
       file("/var/log/vmware/admin.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/ciq-firstboot.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/ciq.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/diskadd.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/lastupdate.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/mod_jk.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vcops-admin.cmd.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vcops-admin.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vcops-firstboot.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vcops-watch.log" log_prefix("vcops-ui: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vcops-ui);
        destination(remote_syslog);
};
__VCOPSUI__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVCOPSANA() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VCOPSANA__

${UNIQUE_CONFIGURE_STRING}
source vcops-ana {
       file("/var/log/vmware/diskadd.log" log_prefix("vcops-ana: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vcops-admin.log" log_prefix("vcops-ana: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vcops-firstboot.log" log_prefix("vcops-ana: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vcops-watch.log" log_prefix("vcops-ana: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vcops-ana);
        destination(remote_syslog);
};
__VCOPSANA__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVCO() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VCO__

${UNIQUE_CONFIGURE_STRING}
source vco {
       file("/opt/vmo/app-server/server/vmo/log/boot.log" log_prefix("vco: ") follow_freq(1) flags(no-parse));
       file("/opt/vmo/app-server/server/vmo/log/console.log" log_prefix("vco: ") follow_freq(1) flags(no-parse));
       file("/opt/vmo/app-server/server/vmo/log/server.log" log_prefix("vco: ") follow_freq(1) flags(no-parse));
       file("/opt/vmo/app-server/server/vmo/log/script-logs.log" log_prefix("vco: ") follow_freq(1) flags(no-parse));
       file("/opt/vmo/configuration/jetty/logs/jetty.log" log_prefix("vco: ") follow_freq(1) flags(no-parse));
};
	
# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vco);
        destination(remote_syslog);
};
__VCO__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVCSA() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VCSA__

${UNIQUE_CONFIGURE_STRING}
source vcsa {
       file("/var/log/vmware/vpx/vpxd.log" log_prefix("vcsa: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vpx/vpxd-alert.log" log_prefix("vcsa: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vpx/vws.log" log_prefix("vcsa: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vpx/vmware-vpxd.log" log_prefix("vcsa: ") follow_freq(1) flags(no-parse));
       file("/var/log/vmware/vpx/inventoryservice/ds.log" log_prefix("vcsa: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vcsa);
        destination(remote_syslog);
};
__VCSA__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVCCServer() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VCC_SERVER__

${UNIQUE_CONFIGURE_STRING}
source vcc-server {
       file("/opt/vmware/hcserver/logs/hcs.log" log_prefix("vcc-server: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vcc-server);
        destination(remote_syslog);
};
__VCC_SERVER__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVCCNode() {
	grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
	if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
		cat >> ${SYSLOG_NG_CONF} << __VCC_NODE__

${UNIQUE_CONFIGURE_STRING}
source vcc-node {
       file("/opt/vmware/hcagent/logs/hca.log" log_prefix("vcc-node: ") follow_freq(1) flags(no-parse));
};
 
# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};
 
log {
        source(vcc-node);
        destination(remote_syslog);
};
__VCC_NODE__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
	else
		echo -e "\n${ALREADY_CONFIGURE_STRING}"
	fi 
}

configureVMA() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VMA__

${UNIQUE_CONFIGURE_STRING}
source vma {
       file("/var/log/vmware/vma/vifpd.log" log_prefix("vma: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vma);
        destination(remote_syslog);
};
__VMA__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVDP() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VDP__

${UNIQUE_CONFIGURE_STRING}
source vdp {
       file("/space/avamar/var/log/av_boot.rb.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/space/avamar/var/log/dpnctl.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/space/avamar/var/log/dpnnetutil-av_boot.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/log/dpnctl.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/log/av_boot.rb.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/log/av_boot.rb.err.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/log/dpnnetutil-av_boot.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/avi/server_log/flush.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/avi/server_log/avinstaller.log.0" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/vdr/server_logs/vdr-server.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/vdr/server_logs/vdr-configure.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamar/var/flr/server_logs/flr-server.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/data01/cur/err.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamarclient/bin/logs/VmMgr.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamarclient/bin/logs/MountMgr.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamarclient/bin/logs/VmwareFlrWs.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
       file("/usr/local/avamarclient/bin/logs/VmwareFlr.log" log_prefix("vdp: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vdp);
        destination(remote_syslog);
};
__VDP__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}


configureVR() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VR__

${UNIQUE_CONFIGURE_STRING}
source vr {
       file("/var/log/vmware/hbrsrv.log" log_prefix("vr: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vr);
        destination(remote_syslog);
};
__VR__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

configureVCD() {
        grep "${UNIQUE_CONFIGURE_STRING}" ${SYSLOG_NG_CONF} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
echo "Configuring ${SYSLOG_NG_CONF} ..."
                cat >> ${SYSLOG_NG_CONF} << __VR__

${UNIQUE_CONFIGURE_STRING}
source vcd {
       file("/opt/vmware/vcloud-director/logs/vcloud-container-debug.log" log_prefix("vcd: ") follow_freq(1) flags(no-parse));
       file("/opt/vmware/vcloud-director/logs/vcloud-container-info.log" log_prefix("vcd: ") follow_freq(1) flags(no-parse));
       file("/opt/vmware/vcloud-director/logs/jmx.log" log_prefix("vcd: ") follow_freq(1) flags(no-parse));
};

# Remote Syslog Host
destination remote_syslog {
       udp("${LOG_INSIGHT}" port (514));
};

log {
        source(vcd);
        destination(remote_syslog);
};
__VR__
echo "Restarting syslog client ..."
/etc/init.d/syslog restart
        else
                echo -e "\n${ALREADY_CONFIGURE_STRING}"
        fi
}

VMW_SOLUTION=$1
LOG_INSIGHT=$2


if [ $# -ne 2 ]; then 
	usage
else
	case ${VMW_SOLUTION} in
		vin)
		configureVIN
		;;
		vcops-ui)
		configureVCOPSUI
		;;
		vcops-ana)
		configureVCOPSANA
		;;
		vco)
		configureVCO
		;;
		vcsa)
		configureVCSA
		;;
		vcc-server)
		configureVCCServer
		;;
		vcc-node)
		configureVCCNode
		;;
		vma)
		configureVMA
		;;
		vdp)
		configureVDP
		;;
		vr)
		configureVR
		;;
		vcd)
		configureVCD
		;;
		*)
		usage
		;;
	esac
fi
