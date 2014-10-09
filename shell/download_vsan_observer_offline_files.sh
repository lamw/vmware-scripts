#!/bin/bash
# William Lam
# www.virtuallyghetto.com

EXTERNAL_JS_LIB_URLS=(
https://ajax.googleapis.com/ajax/libs/angularjs/1.1.5/angular.min.js
https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datepicker/1.3.0/js/bootstrap-datepicker.min.js
https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js
https://cdnjs.cloudflare.com/ajax/libs/d3/3.4.6/d3.min.js
https://code.jquery.com/jquery-1.9.1.min.js
http://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min.map
https://code.jquery.com/ui/1.9.1/jquery-ui.min.js
https://code.jquery.com/jquery.js
)

EXTERNAL_CSS_LIB_URLS=(
https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.no-icons.min.css
https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datepicker/1.3.0/css/datepicker.min.css
https://netdna.bootstrapcdn.com/font-awesome/3.1.1/css/font-awesome.css
)

EXTERNAL_FONT_LIB_URLS=(
http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.2.0/fonts/fontawesome-webfont.eot
http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.2.0/fonts/fontawesome-webfont.svg
http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.2.0/fonts/fontawesome-webfont.ttf
http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.2.0/fonts/fontawesome-webfont.woff
http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.2.0/fonts/FontAwesome.otf
)

EXTERNAL_LIB_DIR=$(pwd)/externallibs

if [ -e ${EXTERNAL_LIB_DIR} ]; then
        echo "It looks like ${EXTERNAL_LIB_DIR} exists already, please delete and re-run script"
        exit 1
fi

echo -e "\nCreating ${EXTERNAL_LIB_DIR}/{js,css,font} directories ..."
mkdir -p ${EXTERNAL_LIB_DIR}/{js,css,font}

echo -e "\nDownloading Javascript files ..."
cd ${EXTERNAL_LIB_DIR}/js
for i in ${EXTERNAL_JS_LIB_URLS[@]}
do
        echo "Downloading $i ..."
        curl -O ${i} > /dev/null 2>&1
done

echo -e "\nDownloading CSS files ..."
cd ${EXTERNAL_LIB_DIR}/css
for i in ${EXTERNAL_CSS_LIB_URLS[@]}
do
        echo "Downloading $i ..."
        curl -O ${i} > /dev/null 2>&1
done

echo -e "\nDownloading FONT files ..."
cd ${EXTERNAL_LIB_DIR}/font
for i in ${EXTERNAL_FONT_LIB_URLS[@]}
do
        echo "Downloading $i ..."
        curl -O ${i} > /dev/null 2>&1
done
echo