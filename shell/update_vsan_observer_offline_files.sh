#!/bin/bash
# William Lam
# www.virtuallyghetto.com

VSAN_OBSERVER_HOME=/opt/vmware/rvc/lib/rvc/observer
EXTERNAL_LIB_DIR=externallibs
VSAN_OBSERVER_STAT_FILE=${VSAN_OBSERVER_HOME}/stats.erb.html
VSAN_OBSERVER_GRAPH_FILE=${VSAN_OBSERVER_HOME}/graphs.html
VSAN_OBSERVER_HISTORY_FILE=${VSAN_OBSERVER_HOME}/history.erb.html
VSAN_OBSERVER_LOGIN_FILE=${VSAN_OBSERVER_HOME}/login.erb.html
VSAN_RB_FILE=/opt/vmware/rvc/lib/rvc/modules/vsan.rb

if [ ! -e ${EXTERNAL_LIB_DIR} ]; then
        echo "${EXTERNAL_LIB_DIR} does not exists!"
        exit 1
fi

if [ -e ${VSAN_OBSERVER_HOME}/${EXTERNAL_LIB_DIR} ]; then
        echo "Removing ${VSAN_OBSERVER_HOME}/${EXTERNAL_LIB_DIR} ..."
        rm -rf ${VSAN_OBSERVER_HOME}/${EXTERNAL_LIB_DIR}
fi

echo -e "\nMoving ${EXTERNAL_LIB_DIR} to ${VSAN_OBSERVER_HOME} ..."
mv -f ${EXTERNAL_LIB_DIR} ${VSAN_OBSERVER_HOME}

cp ${VSAN_OBSERVER_STAT_FILE} ${VSAN_OBSERVER_STAT_FILE}.bak
echo -e "\nUpdating ${VSAN_OBSERVER_STAT_FILE} file ..."
sed -i "s#https://code.jquery.com/jquery-1.9.1.min.js#${EXTERNAL_LIB_DIR}/js/jquery-1.9.1.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js#${EXTERNAL_LIB_DIR}/js/bootstrap.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://code.jquery.com/jquery-1.9.1.min.js#${EXTERNAL_LIB_DIR}/js/jquery-1.9.1.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js#${EXTERNAL_LIB_DIR}/js/bootstrap.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3.min.js#${EXTERNAL_LIB_DIR}/js/d3.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://ajax.googleapis.com/ajax/libs/angularjs/1.1.5/angular.min.js#${EXTERNAL_LIB_DIR}/js/angular.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/font-awesome/3.1.1/css/font-awesome.css#${EXTERNAL_LIB_DIR}/js/font-awesome.css#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://code.jquery.com/ui/1.9.1/jquery-ui.min.js#${EXTERNAL_LIB_DIR}/js/jquery-ui.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datepicker/1.3.0/js/bootstrap-datepicker.min.js#${EXTERNAL_LIB_DIR}/js/bootstrap-datepicker.min.js#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.no-icons.min.css#${EXTERNAL_LIB_DIR}/css/bootstrap-combined.no-icons.min.css#g" ${VSAN_OBSERVER_STAT_FILE}
sed -i "s#https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datepicker/1.3.0/css/datepicker.min.css#${EXTERNAL_LIB_DIR}/css/datepicker.min.css#g" ${VSAN_OBSERVER_STAT_FILE}
cp ${VSAN_OBSERVER_STAT_FILE}.bak ${VSAN_OBSERVER_STAT_FILE}

cp ${VSAN_OBSERVER_GRAPH_FILE} ${VSAN_OBSERVER_GRAPH_FILE}.bak
echo -e "\nUpdating ${VSAN_OBSERVER_GRAPH_FILE} file ..."
sed -i "s#https://code.jquery.com/jquery-1.9.1.min.js#${EXTERNAL_LIB_DIR}/js/jquery-1.9.1.min.js#g" ${VSAN_OBSERVER_GRAPH_FILE}
sed -i "s#https://code.jquery.com/ui/1.9.1/jquery-ui.min.js#${EXTERNAL_LIB_DIR}/js/jquery-ui.min.js#g" ${VSAN_OBSERVER_GRAPH_FILE}
sed -i "s#https://ajax.googleapis.com/ajax/libs/angularjs/1.1.5/angular.min.js#${EXTERNAL_LIB_DIR}/js/angular.min.js#g" ${VSAN_OBSERVER_GRAPH_FILE}
sed -i "s#https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3.min.js#${EXTERNAL_LIB_DIR}/js/d3.min.js#g" ${VSAN_OBSERVER_GRAPH_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.no-icons.min.css#${EXTERNAL_LIB_DIR}/css/bootstrap-combined.no-icons.min.css#g" ${VSAN_OBSERVER_GRAPH_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/font-awesome/3.1.1/css/font-awesome.css#${EXTERNAL_LIB_DIR}/css/font-awesome.css#g" ${VSAN_OBSERVER_GRAPH_FILE}
cp ${VSAN_OBSERVER_GRAPH_FILE}.bak ${VSAN_OBSERVER_GRAPH_FILE}

cp ${VSAN_OBSERVER_HISTORY_FILE} ${VSAN_OBSERVER_HISTORY_FILE}.bak
echo -e "\nUpdating ${VSAN_OBSERVER_HISTORY_FILE} file ..."
sed -i "s#https://code.jquery.com/jquery.js#${EXTERNAL_LIB_DIR}/js/jquery.js#g" ${VSAN_OBSERVER_HISTORY_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js#${EXTERNAL_LIB_DIR}/js/bootstrap.min.js#g" ${VSAN_OBSERVER_HISTORY_FILE}
sed -i "s#https://code.jquery.com/jquery-1.9.1.min.js#${EXTERNAL_LIB_DIR}/js/jquery-1.9.1.min.js#g" ${VSAN_OBSERVER_HISTORY_FILE}
sed -i "s#https://code.jquery.com/ui/1.9.1/jquery-ui.min.js#${EXTERNAL_LIB_DIR}/js/jquery-ui.min.js#g" ${VSAN_OBSERVER_HISTORY_FILE}
sed -i "s#https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3.min.js#${EXTERNAL_LIB_DIR}/js/d3.min.js#g" ${VSAN_OBSERVER_HISTORY_FILE}
sed -i "s#https://ajax.googleapis.com/ajax/libs/angularjs/1.1.5/angular.min.js#${EXTERNAL_LIB_DIR}/js/angular.min.js#g" ${VSAN_OBSERVER_HISTORY_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/font-awesome/3.1.1/css/font-awesome.css#${EXTERNAL_LIB_DIR}/css/font-awesome.css#g" ${VSAN_OBSERVER_HISTORY_FILE}
cp ${VSAN_OBSERVER_HISTORY_FILE}.bak ${VSAN_OBSERVER_HISTORY_FILE}

cp ${VSAN_OBSERVER_LOGIN_FILE} ${VSAN_OBSERVER_LOGIN_FILE}.bak
echo -e "\nUpdating ${VSAN_OBSERVER_LOGIN_FILE} file ..."
sed -i "s#https://code.jquery.com/jquery.js#${EXTERNAL_LIB_DIR}/js/jquery.js#g" ${VSAN_OBSERVER_LOGIN_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js#${EXTERNAL_LIB_DIR}/js/bootstrap.min.js#g" ${VSAN_OBSERVER_LOGIN_FILE}
sed -i "s#https://code.jquery.com/jquery-1.9.1.min.js#${EXTERNAL_LIB_DIR}/js/jquery-1.9.1.min.js#g" ${VSAN_OBSERVER_LOGIN_FILE}
sed -i "s#https://code.jquery.com/ui/1.9.1/jquery-ui.min.js#${EXTERNAL_LIB_DIR}/js/jquery-ui.min.js#g" ${VSAN_OBSERVER_LOGIN_FILE}
sed -i "s#https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3.min.js#${EXTERNAL_LIB_DIR}/js/d3.min.js#g" ${VSAN_OBSERVER_LOGIN_FILE}
sed -i "s#https://ajax.googleapis.com/ajax/libs/angularjs/1.1.5/angular.min.js#${EXTERNAL_LIB_DIR}/js/angular.min.js#g" ${VSAN_OBSERVER_LOGIN_FILE}
sed -i "s#https://netdna.bootstrapcdn.com/font-awesome/3.1.1/css/font-awesome.css#${EXTERNAL_LIB_DIR}/css/font-awesome.css#g" ${VSAN_OBSERVER_LOGIN_FILE}
cp ${VSAN_OBSERVER_LOGIN_FILE}.bak ${VSAN_OBSERVER_LOGIN_FILE}

echo -e "\nUpdating ${VSAN_RB_FILE} file ..."
cp ${VSAN_RB_FILE} ${VSAN_RB_FILE}.bak
sed -i "s#File.basename)#File.basename(f))#" ${VSAN_RB_FILE}
cp ${VSAN_RB_FILE}.bak ${VSAN_RB_FILE}