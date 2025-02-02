/*
 *  Copyright (c) 2012-2024 Broadcom. All Rights Reserved.
 *  Broadcom Confidential. The term "Broadcom" refers to Broadcom Inc.
 *  and/or its subsidiaries.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may not
 *  use this file except in compliance with the License.  You may obtain a copy
 *  of the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS, without
 *  warranties or conditions of any kind, EITHER EXPRESS OR IMPLIED.  See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */

/*
 * JS util functions for websso
 */

// namespace to prevent polluting the world

// -------------vars --------------------
   var isMac = (navigator.userAgent.indexOf('Mac OS X') !== -1);
   var isLinux = (navigator.userAgent.indexOf('Linux') !==-1 ||
                                    navigator.userAgent.indexOf('X11') !==-1);

   // jaked using build number 2137170  for CIP_CLN = 2952709 we need to
   // update manually once CLN changes
   var cipBuildVersion = '6.7.0';
   var _cspId = '';

   var _VersionStr = null;
   var _ishtml5LocalStorageSupported = null;
   var _isLogInitialized = false;
   var _xml = null;
   var userName = "";
   var _url = null;
   var _sspiCtxId = null;
   var _rsaSessionID = null;
   var isFederationLogin = false;

   var api = {
      logging: {},
      activeTarget: {},
      session: {},
      sspi: {}
   }
   //snanda : the conn object will be used for all CSD operation
   var conn = new ApiConnection();

   // Enabling 'enter' on the submit button.
   $(document).keypress(function(e){
      if (e.which == 13){
         submitentry();
      }
   });

   // things to do when document is ready
   $(document).ready(function() {
      // assigning placeholder value to password field
      $('#password').prop('placeholder', password_label);

      federationLoginFlow();

   });

   var webssoLoginFlow = function webssoLoginFlow() {

      // if both logon banner title and content are set, display logon banner on websso
      if (isLogonBannerEnabled()) {
         var logonMessageText = tenant_logonbanner_title.replace(/'/g, "&apos;");
         var logonBannerTitleEle = document.getElementById('logonBannerID').querySelector('#logonBannerTitle');
         logonBannerTitleEle.innerHTML = logonMessageText;
         var logonMessageTitleEle = document.getElementById('logonMessageDiv').querySelector('#logonBannerTitle');
         logonMessageTitleEle.innerHTML = logonMessageText;
         if (!logonBannerCheckboxEnabled) {
            // hide checkbox and agreementMsg if checkbox is not enabled
            $('#logonBannerID').hide();
            $('#logonMessageDiv').show();
         } else {
            $('#logonBannerID').show();
            $('#logonMessageDiv').hide();
         }
      } else {
         $('#logonBannerID').hide();
         $('#logonMessageDiv').hide();
      }

      if (tlsclient_auth == "true") {
         $('#smartcardCheckbox').attr('disabled', false);
         var smartcardCheckbox = document.getElementById('smartcardCheckbox');
         checkboxDisableChange(smartcardCheckbox);

         //Remove username and pw widgets if both username/password or RSA are not enabled.
         if (password_auth == "false" && rsa_am_auth == "false") {
            //disable username field if hint is not enabled
            document.getElementById("username").style.display = 'none';
            document.getElementById("password").style.display = 'none';
         }
         //default to use smartcard authn if availble.
         var smartcardEle = document.getElementById('smartcardCheckbox');
         smartcardEle.checked = true;
         enableSmartcard(smartcardEle);
      } else {
         var smartcardIDEle = document.getElementById("smartcardID");
         smartcardIDEle.parentNode.removeChild(smartcardIDEle);
         // Disable login button on page load unless smartcard authn is on
         $('#submit').prop('disabled', true);
      }

      if (rsa_am_auth == "false") {
         var rsaamIDEle = document.getElementById("rsaamID");
         rsaamIDEle.parentNode.removeChild(rsaamIDEle);
      } else {
         $('#rsaamCheckbox').attr('disabled', false);
         var rsaamCheckbox = document.getElementById('rsaamCheckbox');
         checkboxDisableChange(rsaamCheckbox);

         //default to select securID authentication if smartcard is not enabled.
         if (tlsclient_auth != "true") {
            var rsaCheckbox = document.getElementById('rsaamCheckbox');
            rsaCheckbox.checked = true;
            enableRsaam(rsaCheckbox);
            displayRsaamMessage(true);
         }
      }
      // Make sure document is ready before checking if cookies are enabled
      // and displaying the related error.
      if (!areCookiesEnabled()) {
         console.log('Failed to write cookie on document');
      }

      //on change of username enable login button
      if (password_auth == "true" || rsa_am_auth == "true") {
         $('#username').on('keyup keypress blur change', enableLoginButton);
      }
      if (isFederationLogin) {
         enableLoginButton();
      }
      //on change of smartcard enable login button
      if (tlsclient_auth == "true") {
         $('#smartcardCheckbox').on('change', enableLoginButton);
      }

      setCSDInstalled();
      enableLoginButton();

      //create the actual CSD object. this will also enable/disable
      //sspi depending upon whether the plugin call succeeds or not
      if (!isMac && !isLinux) {
         createCsdInstance();
      }

   };

   // Validation that checks if the browser and OS are supported.
   // At the time of writing a minimum of IE10, Firefox 34 or
   // Chrome 39 are required on Windows. A minimum of Firefox 34
   // or Chrome 39 are required on Mac OS X.
   var isBrowserSupportedVC = function isBrowserSupportedVC(){
      var chromeReg = /Mozilla\/.*? \((Windows|Macintosh)(.*?) AppleWebKit\/(\d.*?).*?Chrome\/(.*?) Safari\/(.*)/i;
      var CHROME_VERSION_INDEX = 4;
      var ieReg = /Mozilla\/(.*?) \((compatible|Windows;.*?); (MSIE) ([0-9]*?)\.([0-9]*?);? (.*?)?;? ?(.*?)*\) ?( .*?)?/i;
      var IE_VERSION_INDEX = 4;
      var ie11Reg = /Trident\/.*rv:([0-9]{1,}[\.0-9]{0,})/i;
      var IE11_VERSION_INDEX = 1;
      var firefoxReg = /Mozilla\/(.*?) \(.*?(Windows|Macintosh)(.*?) Gecko\/(\d.*?) ((\w.*)\/(\d[^ ]*))?/i;
      var FF_VERSION_INDEX = 7;
      var usrAgent = navigator.userAgent;
      var result;
      if ((result = chromeReg.exec(usrAgent)) !== null) {
         if (result[CHROME_VERSION_INDEX].split(".")[0] >= 39) {
            return true;
         }
      }
      if ((result = ieReg.exec(usrAgent)) !== null) {
         if (result[IE_VERSION_INDEX] >= 10) {
            return true;
         }
      }
      if ((result = ie11Reg.exec(usrAgent)) !== null) {
         if (result[IE11_VERSION_INDEX] >= 11) {
            return true;
         }
      }
      if ((result = firefoxReg.exec(usrAgent)) !== null) {
         if (result[FF_VERSION_INDEX] >= 34) {
            return true;
         }
      }
      return false;
   };

   function handleApiResult(result, err) {
      var msg = result != null ? result : err;
      if (!msg) {
         console.log("Empty result message?");
         return;
      }
      var text = "Object Id: " + msg.requestObjectId + ", Request Id: " + msg.requestId;
      if (err) {
         text += ", Error occurred (" + err.errorCode + "): " + err.message;
      } else {
         text += ", Status (" + result.statusCode + "): " + result.result;
      }
      doLog("handleApiResult : " + text);
   }

   function onAppInit(result, err) {
     if (err) {
        handleApiResult(result, err);
        setCSDInstalled();
        return;
     }
     this._VersionStr = result["version"] + "." + result["build"];
     if (result["version"] != null) {
         cipBuildVersion = result["version"];
     }
     doLog("onAppInit : using CIP Build " + this._VersionStr);
     setCSDInstalled();
   }

   function createCsdInstance() {
      if (conn.isOpen || conn.isOpenning) {
         return;
      }
      doLog("createCsdInstance : Opening the first connection to WebSocket server");
      conn.open();

      conn.onopen = function (evt) {
         console.log("CSD Plugin : Connection Open");
         api.session = new SessionApi(conn);
         api.config = new ConfigApi(conn);
         api.sspi = new SSPIApi(conn);
         //Initiate the logger. log files are kept
         // @%ProgramData%\VMware\vSphere Web Client\ui\sessions\... login.log
         ActivateLogger();

         api.session.init(
            {appName:"webSSO-NGC"},
            onAppInit
         );
      };

      conn.onerror = function(evt) {
         var message = evt == null ? "None" : evt.data;
         console.log("No Plugin Detected ... Connection error: " + message);
         doLog("No Plugin Detected ... Connection error: " + message);
         setCSDInstalled();
      };

      conn.onclose = function(evt) {
         var message = evt == null ? "None" : evt.data;
         console.log("Connection Closed: " + message);
         doLog("Connection Closed: " + message);
         setCSDInstalled();
      };
   }

   // if CIP is installed, writes to browser localStorage to set var "vmwCIPInstalled" to "true"
   //   then display a redirect link to KB.
   // if CIP is not installed, set var to "false"
   var setCSDInstalled = function setCSDInstalled(){
      if (this._VersionStr != null || !isVCLogin()) {
         if (!isMac && !isLinux) {
             var cspDownloadRedirectLink = 'https://www.vmware.com/security/advisories/VMSA-2024-0003.html';
             $('#footer').css('display', 'block');
             $('#downloadCIPRedirectToKBlink').attr('href', cspDownloadRedirectLink);
             $('#downloadCIPRedirectToKBlink').empty();
             $('#downloadCIPRedirectToKBlink').append(document.createTextNode(downloadCIPRedirectToKBMsg));
             $('#downloadCIPRedirectToKBlinkBox').show();
             $('#downloadCIPRedirectToKBforAriaLive').append("<div tab-index=\"-1\" style=\"top:0;left:-2px;width:1px;height:1px;position:absolute;overflow:hidden;\">Warning " + downloadCIPRedirectToKBMsg + "</div>");
         }
      }
   };

   var isVCLogin =   function isVCLogin() {
      if (tenant_brandname == null || tenant_brandname == '') {
         return true;
      } else {
         return false;
      }
   };

   var federationLoginFlow = function federationLoginFlow() {
      if (isDiscovery && isDiscovery.trim() == "true") {
         showIdpSignInPage();
      }
      showIdpErrorAlert();
      webssoLoginFlow();
   };

   //-------------- Cookies!!

   // create a Cookie
   var createCookie =    function createCookie(name, value, days) {
            var expires;
            if (days) {
               var date = new Date();
               date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
               expires = '; expires=' + date.toGMTString();
            } else {
               expires = '';
            }
            document.cookie = name + '=' + value + expires + '; path=/';
        };

   var readCookie =   function readCookie(name) {
           var nameEQ = name + '=';
           var ca = document.cookie.split(';');
           for (var i = 0; i < ca.length; i++) {
               var c = ca[i];
               while (c.charAt(0) == ' ') c = c.substring(1, c.length);
               if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
           }
           return null;
        };

   var eraseCookie =    function eraseCookie(name) {
           createCookie(name, '', -1);
       };

   var areCookiesEnabled =   function areCookiesEnabled() {
            var r = false;
            createCookie('LoginTest', 'HelloWorld', 1);
            if (readCookie('LoginTest') != null) {
               r = true;
               eraseCookie('LoginTest');
            }
            return r;
         };

   var enableLoginButton = function enableLoginButton() {
            var userEle = document.getElementById('username');
            var smartcardEle = document.getElementById('smartcardCheckbox');
            if ( (userEle != null && $.trim($('#username').val()).length > 0)  ||
               (smartcardEle != null && smartcardEle.checked==true) ||
               isFederationLogin) {
                  $('#submit').prop('disabled', false);
            } else {
               $('#submit').prop('disabled', true);
            }
         };

   var checkboxDisableChange = function checkboxDisableChange(checkboxEle) {
      var checkboxLabel = checkboxEle.parentElement.getElementsByTagName("label")[0];
      if (checkboxEle.disabled == true) {
         checkboxLabel.style.opacity = '0.5';
      }
      else {
         checkboxLabel.style.opacity = '1';
      }
   };

   // Status = true if you want the fields to be disabled.
   var disableFields = function disableFields(status) {
            var userEle = document.getElementById('username');
            var passwordEle = document.getElementById('password');
            if ( userEle != null && passwordEle != null) {
                if (password_auth == "true" || rsa_am_auth == "true") {
                   passwordEle.disabled = status;
                } else {
                   //Not allow to enter user name unless the pw authentication is available
                   passwordEle.disabled = true;
                }
            }
            disableUserNameEle(status);
            document.getElementById('submit').disabled = status;

            var smartcardEle = document.getElementById('smartcardCheckbox');
            if ( smartcardEle != null) {
                smartcardEle.disabled = status;
                checkboxDisableChange(smartcardEle);
                if (smartcardEle.checked && passwordEle != null) {
                    passwordEle.disabled = true;
                }
            }
            var rsaamEle = document.getElementById('rsaamCheckbox');
            if ( rsaamEle != null) {
                rsaamEle.disabled = status;
                checkboxDisableChange(rsaamEle);
            }
         };
   var disableUserNameEle = function disableUserNameEle(disable) {
       var userEle = document.getElementById('username');
       var smartcardEle = document.getElementById('smartcardCheckbox');

       if (userEle == null) {
           return;
       }
       if (disable == true) {
           userEle.disabled = true;
       }
       //enable only if user ele is needed, i.e. when not using smartcard.
       else if (smartcardEle == null ||
           (smartcardEle != null && !smartcardEle.checked)) {
           userEle.disabled = false;
       }
   }

     // return true if only smartcard authentication is supported
     var onlySmartcardEnabled = function onlySmartcardEnabled() {
              if (password_auth == "true" || rsa_am_auth == "true") {
                  return false;
              } else {
                  return true;
              }
           }
     var enableSmartcard = function enableSmartcard(cb) {
         // reset login guide text
         var response = document.getElementById('response');
         response.innerHTML = '';
         response.style.display = 'none';
         clearInfoText();

         var usernameField = document.getElementById('username');
         var passwordField = document.getElementById('password');

         usernameField.placeholder = username_placeholder;

         if (usernameField.placeholder.length == 0) {
            usernameField.placeholder = getDefaultUsernamePlaceholder();
         }

         //keep it checked if this is the only authentication method.
         if (onlySmartcardEnabled()) {
             cb.checked = true;
         }

         if (usernameField != null && passwordField != null) {
             if (cb.checked) {
                 usernameField.disabled = true;
                 passwordField.disabled = true;
              } else if (password_auth == "true" || rsa_am_auth == "true") {
                 //usernameField should always be avail if cb is enabled
                 usernameField.disabled = false;
                 passwordField.disabled = false;
              }
         }

         //uncheck RSA checkbox, as only one auth method could be selected.
         var rsaamCheckboxEle = document.getElementById('rsaamCheckbox');
         if (rsaamCheckboxEle != null) {
             if (cb.checked) {
                 rsaamCheckboxEle.checked = false;
             } else {
                 rsaamCheckboxEle.disabled = false;
                 checkboxDisableChange(rsaamCheckboxEle);
             }
         }

      };

     var onlyRsaamEnabled = function onlySmartcardEnabled() {
              if (password_auth == "true" || tlsclient_auth == "true") {
                  return false;
              } else {
                  return true;
              }
           }

     var enableRsaam = function enableRsaam(cb) {
           var usernameField = document.getElementById('username');
           var passwordField = document.getElementById('password');

           //keep it checked if this is the only authentication method.
           if (onlyRsaamEnabled()) {
               cb.checked = true;
           }

           if (usernameField != null && passwordField != null) {
               if (cb.checked) {
                   usernameField.disabled = false;
                   passwordField.disabled = false;
                   document.getElementById("password").placeholder = rsaam_passcode_label;
                } else {
                   //password is the non-user definable label. so this is secure.
                   document.getElementById("password").placeholder = password_label;
                }
           }
           displayRsaamMessage(cb.checked? true:false);

           //uncheck smartcard, as only one auth method could be selected.
           var smartcardCheckboxEle = document.getElementById('smartcardCheckbox');
           if (smartcardCheckboxEle != null) {
               if (cb.checked) {
                   smartcardCheckboxEle.checked = false;
               }
           }
        };

   var readyAcceptingRSANextCode = function readyAcceptingRSANextCode(self) {
           var rsaamCheckboxEle = document.getElementById('rsaamCheckbox');
           rsaamCheckboxEle.disabled = false;
           checkboxDisableChange(rsaamCheckboxEle);
           document.getElementById('submit').disabled = false;
           document.getElementById('username').disabled = false;
           document.getElementById('password').disabled = false
           progressStart(false);
           document.getElementById('response').style.display = 'flex';
           var castleError = self.getResponseHeader('CastleError');
           response.innerHTML = castleError != null ? Base64.decode(castleError) : "Please submit the next passcode";

           console.log('Enter next passcode.');
           doLog("Enter next passcode.");
        };
   // handle the sso response
   var handleResponse = function (evt) {
            var self = this;
            var rsaamCheckbox = document.getElementById('rsaamCheckbox');
            //var smartcardLogin = smartcardCheckbox != null && smartcardCheckbox.checked;
            var rsaamLogin = rsaamCheckbox != null && rsaamCheckbox.checked;

            if (self.readyState == 4){
               // process response
               var rsaSessionID = null;

               if (self.status == 401) {
                  // Multiple leg authentication
                  var authHeader = self.getResponseHeader('CastleAuthorization');
                  if (authHeader != null) {
                     authHeaderParts = authHeader.split(' ');
                     if (rsaamLogin) {
                         // RSA AM NextCode mode, first leg will return 401 with rsa sessionID in header.
                         if (authHeaderParts.length == 2 && authHeaderParts[0] == 'RSAAM') {
                             rsaSessionID = authHeaderParts[1];
                         }
                     }
                  }
               }

               if (self.status == 302) {
                  // redirect back to original url
                  document.location = originalurl;
               } else if (rsaSessionID != null) {
                  // next code mode.
                  _rsaSessionID = rsaSessionID;
                  readyAcceptingRSANextCode(this);
               } else {
                  //all non second leg scenarios.
                  var response = document.getElementById('response');
                  var progressBar = document.getElementById('progressBar');
                  var castleError = null;

                  if (self.status == 200) {
                     if (protocol === 'openidconnect' && responseMode !== 'form_post') {
                        document.location = self.responseText;
                     } else {
                        var postForm = document.getElementById('postForm');
                        postForm.style.display = 'none';
                        postForm.innerHTML = self.responseText;
                     }
                  } else {
                     // display the result
                     response.style.display = 'flex';
                     progressStart(false);
                     castleError = self.getResponseHeader('CastleError');
                     response.innerHTML = castleError != null ? Base64.decode(castleError) : self.statusText;
                     doLog("Error received during negotiation. Msg : [ " + response.innerHTML + " ]");
                     disableFields(false);
                  }

                  if (!(protocol === 'openidconnect' && responseMode !== 'form_post')) {
                     // if SamlPostForm is present, submit it
                     var samlPostForm = document.getElementById('SamlPostForm');

                     if (samlPostForm != null) {
                        samlPostForm.submit();
                     } else {
                        // Re-enable everything since the user will have to attempt
                        // logging in again.
                        progressStart(false);
                        disableFields(false);

                        //give a generic error
                        response.style.display = 'flex';
                        if (castleError == null) {
                           response.innerHTML = error;
                        }
                        doLog("did the login fail? if using SSPI - ensure the logged in user can login to the SSO service");
                     }
                  }
               }
            }
   };

   function displayRsaamMessage(messageOn) {
       if (messageOn == true && rsaam_reminder.length > 0) {
           showInfoText(rsaam_reminder);
       } else {
           document.getElementById('infoID').style.display = 'none';
       }
   }

   var progressStart = function progressStart(doStart) {
      var submitBtn = document.getElementById('submit');
      var progressBar = document.getElementById('progressBar');
      if(doStart == true) {
         submitBtn.style.display = "none";
         progressBar.style.display = "block";
      }
      else {
         submitBtn.style.display = "block";
         progressBar.style.display = "none";
      }
    };

   var showInfoText = function showInfoText(message) {
      var infoElement = document.getElementById('infoID');
      var infoText = document.getElementById('infoText');

      infoElement.style.display = 'block';
      infoText.innerHTML = message;
   };

   var clearInfoText = function clearInfoText() {
      var infoElement = document.getElementById('infoID');
      var infoText = document.getElementById('infoText');
      infoElement.style.display = 'none';
      infoText.innerHTML = '';
   };

   var showErrorText = function showErrorText(error) {
      var response = document.getElementById('response');

      if (error) {
         response.style.display = 'flex';
         response.innerHTML = error;
      }
      else {
         response.style.display = 'none';
      }
   };

   var getDefaultUsernamePlaceholder = function getDefaultUsernamePlaceholder() {
      var usernameLength = usernameText.length;
      if (usernameLength > 0) {
         var username = usernameText.trim();
         if(username.charAt(usernameLength-1) == ':') {
            return username.substr(0, usernameLength-1);
         }
         return username;
      }
      return "";
   };

   var submitentry = function submitentry() {
      // calculate redirect URL
      var originalurl;
      originalurl = document.URL;
      _url = originalurl.replace(searchString, replaceString);

      // get the field values
      var submit = document.getElementById('submit');
      var smartcardCheckbox = document.getElementById('smartcardCheckbox');
      var rsaamCheckbox = document.getElementById('rsaamCheckbox');
      var progressBar = document.getElementById('progressBar');
      var smartcardLogin = smartcardCheckbox != null && smartcardCheckbox.checked;
      var rsaamLogin = rsaamCheckbox != null && rsaamCheckbox.checked;
      var username = (document.getElementById('username') == null)? '': $.trim(document.getElementById('username').value);
      var password = (document.getElementById('password') == null)? '': document.getElementById('password').value;
      doLog("Login started for user : " + username);
      // Note: it is perfectly fine for the password field to be empty.
      if (username != '' || smartcardLogin) {
         if (isLogonBannerEnabled() && logonBannerCheckboxEnabled && !isBannerChecked()) {
            return;
         }

         if ( smartcardLogin ) {
            _url = _url.replace(sso_endpoint, cac_endpoint);
         }

         // Display progress
         progressStart(true);
         clearInfoText();
         var response = document.getElementById('response');
         response.style.display = 'none';
         // create a request
         var xml = new XMLHttpRequest();
         // function to call after the request is completed
         xml.onreadystatechange = handleResponse;
         xml.open('POST', _url, true);
         // Disable the fields.
         disableFields(true);
         _xml = null;
         doLog("Using username password to login");
         unp = username + ':' + password;
         unp = Base64.encode(unp);
         var params = 'CastleAuthorization=';

         //temp solution allowing smartcard authentication test.
         var authType = '';   //default

          if (tlsclient_auth == "true" && document.getElementById('smartcardCheckbox').checked == true) {
             authType = 'TLSClient ' + unp;
          } else if (rsaamLogin) {
             if (_rsaSessionID != null) {
                authType = "RSAAM " + _rsaSessionID+ " "+ unp;
                _rsaSessionID = null;
             } else {
                authType = "RSAAM " + unp;
             }
          } else if (password_auth == "true") {
             authType = 'Basic ' + unp;
          }
          params += encodeURIComponent(authType);

          // disable http caching
          xml.setRequestHeader('Cache-Control', 'no-cache');
          xml.setRequestHeader('Pragma', 'no-cache');
          xml.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
          // send request
          xml.send(params);
      } else {
         doLog("Error : Not ready to login");
      }
   };

   function ActivateLogger () {
      if (api.logTarget) {
         api.logTarget.close();
         api.logTarget = null;
      }
      api.logTarget = new LoggingTargetApi(conn);
      var config = {
         targetName:"login",
         logFileSize: 20000,
         maxLogFiles: 10,
         logTime:"true"
      };
      api.logTarget.setConfig(config, function (result, err) {
         if (err) {
            console.log("Error creating logging target (" + err.errorCode +  "): " + err.message);
            api.logTarget = null;
            return;
         }
         if (api.logTarget != null) {
            console.log("Log Target Activated - (object id = " + api.logTarget.objectId + ")");
            _isLogInitialized = true;
            doLog("Log initialized for websso login");
         }
      });
   }

   function doLog(strLog) {
      if (_isLogInitialized == false) {
         return;
      }
      api.logTarget.log({line:strLog});
   }

   var isBannerChecked = function isBannerChecked() {
      var cb = document.getElementById('logonBannerCheckbox');
      var alertMsg = logonBannerAlertMessage + " " + tenant_logonbanner_title;
      if (cb && cb.checked) {
         clearInfoText();
         return true;
      } else {
         showInfoText(alertMsg);
         return false;
      }
   }

   var isEmptyString = function isEmptyString(data) {
	   // checks for null, undefined, '' and ""
       if (!data) {
           return true;
       };
	   return data.length === 0;
   }

   var isLogonBannerEnabled = function isLogonBannerEnabled() {
	   return !isEmptyString(tenant_logonbanner_title) && !isEmptyString(tenant_logonbanner_content)
   }

   function displayLogonBannerDialog() {
       $('#dialogLogonBanner').html(
               '<pre class="hyphenate">' +
               '<h3 class="title">' + tenant_logonbanner_title + '</h3>' +
               '<span class="dialogContent">' + tenant_logonbanner_content + '</span>' + '</pre>');
       $('#dialogLogonBanner').dialog(
              {
                   width: 650,
                   height: 400,
                   modal: true,
                   draggable: false
              }
       );
       $('.ui-dialog-titlebar').html('<span class="close-button"><img src="../../resources/img/close.png" /></span>');
       $('.close-button').click(function() {
           $('#dialogLogonBanner').dialog( "close" );
       });
   }

   function getQueryParam(name) {
      var value = getQueryParamFromUrl(name, window.location.href);
      if (value !== null && value !== "") {
         try {
            value = decodeURIComponent(value);
         } catch(e) {
            console.error(e);
            value = null;
         }
      }
      return value;
   }

   function getQueryParamFromUrl(name, url) {
      var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)");
      var results = regex.exec(url);
      if (!results || !results[2]) {
          return null;
      }
      return results[2].replace(/\+/g, " ");
   }
