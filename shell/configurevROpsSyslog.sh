#!/bin/bash
# William Lam
# www.virtuallyghetto.com
#
# Product: vRealize Operations Manager 6.0
# Usage: CLI via SSH
# Reference: http://www.virtuallyghetto.com/2015/01/automate-forwarding-of-vrealize-operations-manager-logs-to-syslog-server.html

SYSLOG_SERVER=syslog.primp-industries.com
SYSLOG_SERVER_PORT=514

### DO NOT EDIT BEYOND HERE ###

ANALYTICS_SYSLOG_CONF=/usr/lib/vmware-vcops/user/conf/analytics/log4j.properties
COLLECTOR_SYSLOG_CONF=/usr/lib/vmware-vcops/user/conf/collector/log4j.properties
WEB_SYSLOG_CONF=/usr/lib/vmware-vcops/user/conf/web/log4j.properties
SUITEAPI_SYSLOG_CONF=/usr/lib/vmware-vcops/tomcat-enterprise/webapps/suite-api/WEB-INF/log4j.properties

VROPS_SYSLOG_CONFS=(${ANALYTICS_SYSLOG_CONF} ${COLLECTOR_SYSLOG_CONF} ${WEB_SYSLOG_CONF} ${SUITEAPI_SYSLOG_CONF})

for i in ${VROPS_SYSLOG_CONFS[@]};
do
	echo "Configuring $i ..."
	sed -i 's/log4j.rootLogger.*/log4j.rootLogger = WARN,fileAppender,SYSLOG_SERVER/g' $i
	echo "log4j.appender.SYSLOG_SERVER.layout = org.apache.log4j.PatternLayout" >> $i
	echo "log4j.appender.SYSLOG_SERVER.layout.conversionPattern = %d{ISO8601} - %m%n" >> $i
	echo "log4j.appender.SYSLOG_SERVER.syslogHost = ${SYSLOG_SERVER}:${SYSLOG_SERVER_PORT}" >> $i
	echo "log4j.appender.SYSLOG_SERVER.Facility = LOCAL2" >> $i
	echo "log4j.appender.SYSLOG_SERVER = org.apache.log4j.net.SyslogAppender" >> $i
done

echo "Restart vRealize Operations Manager Service ..."
/etc/init.d/vmware-vcops restart