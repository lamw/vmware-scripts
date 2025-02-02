<%--
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
--%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ page session="false" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd">
<html class="base-app-style">
<!--[if lte IE 8]>
<link rel="stylesheet" type="text/css" href="../../resources/css/loginIE8-7.css"/>
<![endif]-->
<!--[if (gte IE 9)|!(IE)]><!-->
<!--<link href="../../resources/css/login.css" rel="stylesheet"> -->
<!--<![endif]-->
<head>
   <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
   <meta http-equiv="X-UA-Compatible" content="IE=5, IE=8, IE=10">
   <title>Login</title>

   <script type="text/javascript">
      // copying JSP variables to JS
      var protocol = "${protocol}";
      var responseMode = "${responseMode}";
      var tenant_brandname = "${tenant_brandname}";
      var tenant_logonbanner_title = '${tenant_logonbanner_title}'.trim();
      var tenant_logonbanner_content = '${tenant_logonbanner_content}'.trim();
      var logonBannerCheckboxEnabled = '${enable_logonbanner_checkbox}'.trim() == 'true' ? true : false;
      var logonBannerAlertMessage = '${logonBannerAlertMessage}';
      var searchString = "${searchstring}";
      var replaceString = '${replacestring}';
      var error = '${error}';
      var errorSSPI = '${errorSSPI}'
      var spn = "${spn}"
      var cac_endpoint = "${cac_endpoint}";
      var sso_endpoint = "${sso_endpoint}";
      var downloadCIPRedirectToKBMsg = "${downloadCIPRedirectToKB}";

      var tlsclient_auth = '${enable_tlsclient_auth}';
      var password_auth = '${enable_password_auth}';
      var rsa_am_auth = '${enable_rsaam_auth}';
      var rsaam_reminder = '${rsaam_reminder}';
      var rsaam_passcode_label = '${passcode}';
      var password_label = '${password}';
      var usernameText = "${username}";
      var host = window.location.origin;

      // IdP discovery page
      var isDiscovery = "${is_discovery}";
      var indirectFederation = "${indirect_federation}";
      var providerName = "${provider_name}";
      var vcenterIdpId = "${vcenter_idp_id}";
      var welcomeMessage = "${wellcome_message}";
      var signoutMessage = "${signout_message}";
      var redirectMessage = "${redirect_message}";
      var signinUsername = "${signin_username}";
      var signinProvider = "${signin_provider}";
      var signinNext = "${signin_next}";
      var signinLocal = "${signin_local}";
      var signinUsernameFormatError = "${signin_username_format_error}";
      var signinUsernameRequired = "${signin_username_required}";
      var externalIdpErrorMsg = "${ext_idp_err_msg}";
      var providerNameNonDefault = "${provider_name_nondefault}";
      var vcenterIdpIdNonDefault = "${vcenter_idp_id_nondefault}";
      var redirectMessageNonDefault = "${redirect_message_nondefault}";
      var signinProviderNonDefault = "${signin_provider_nondefault}";



      if (tlsclient_auth == "true") {
         var username_label = '${username_encoded}';
         var username_placeholder = '${username_placeholder_encoded}';
      }

   </script>

   <script type="text/javascript" src="../../resources/js/assets/csd_api_common.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_connection.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_base.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_factory.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_config.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_logging.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_session.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_sspi.js"></script>
   <script type="text/javascript" src="../../resources/js/assets/csd_api_sso.js"></script>

   <script type="text/javascript" src="../../resources/js/Base64.js"></script>
   <script type="text/javascript" src="../../resources/js/VmrcPluginUtil.js"></script>
   <script type="text/javascript" src="../../resources/js/jquery-3.6.0.min.js"></script>
   <script type="text/javascript" src="../../resources/js/jquery-ui.min.js"></script>
   <script type="text/javascript" src="../../resources/js/websso.js"></script>
   <script type="text/javascript" src="../../resources/js/idpsignin.js"></script>
   <script type="text/javascript" src="../../resources/js/custom-elements.min.js"></script>
   <script type="text/javascript" src="../../resources/js/clr-icons.min.js"></script>
   <script type="text/javascript" src="../../resources/js/partical.js"></script>
   <link rel="icon" type="image/x-icon" href="../../resources/img/favicon.ico"/>
   <link rel="SHORTCUT ICON" href="../../resources/img/favicon.ico"/>
   <link rel="stylesheet" type="text/css" href="../../resources/css/jquery-ui.min.css">
   <link rel="stylesheet" href="../../resources/css/clr-ui.min.css">
   <link rel="stylesheet" href="../../resources/css/clr-icons.min.css">
   <link rel="stylesheet" href="../../resources/css/clarity-login.css">
   <link rel="stylesheet" href="../../resources/css/idpsignin.css">
</head>

<body>
<div id="bg-banner"></div>
<div class="alert alert-app-level alert-danger" id="idpErrorAlert">
   <div class="alert-items">
       <div class="alert-item static">
           <div class="alert-icon-wrapper">
               <clr-icon class="alert-icon" shape="exclamation-circle"></clr-icon>
            </div>
           <div class="alert-text">${ext_idp_err_msg}</div>
       </div>
   </div>
</div>
<div class="login-wrapper">
   <form id="loginForm" class="login" autocomplete="off">
      <section class="title">
         <span id="titleVmware">Epping vCenter Server</span>
         <span id="tenantBrand" style="display: none;">${tenant_brandname}</span>
      </section>
      <div class="login-group">
         <script type="text/javascript" src="../../resources/js/particles.min.js"></script>
         <input id="username" class="username" type="text" placeholder="${username_placeholder}" value="administrator@vsphere.local">
         <input id="password" class="password" type="password" placeholder="${password_label}" autocomplete="off" value="VMware1!">
         <div id="response" class="error active" style="display:none"></div>
         <div class="alert alert-info" id="infoID" style="display:none">
            <div class="alert-items">
               <div class="alert-item static">
                  <div class="alert-icon-wrapper">
                     <clr-icon class="alert-icon" shape="info-circle"></clr-icon>
                  </div>
                  <span class="alert-text" id="infoText"></span>
               </div>
            </div>
         </div>
         <div id="smartcardID" class="checkbox">
            <input id="smartcardCheckbox" type="checkbox" disabled="false" onchange="enableSmartcard(this);">
            <label id="checkboxLabel" for="smartcardCheckbox">${smartcard}</label>
         </div>
         <div id="rsaamID" class="checkbox">
            <input id="rsaamCheckbox" type="checkbox" disabled="false" onchange="enableRsaam(this);">
            <label id="checkboxLabel" for="rsaamCheckbox">${rsaam}</label>
         </div>
         <div id="logonBannerID" class="checkbox">
            <input id="logonBannerCheckbox" type="checkbox" onclick="isBannerChecked()">
            <label for="logonBannerCheckbox">
               <span id="agreementMsg">${iAgreeTo}</span>
               <a id="logonBannerTitle" class="hyphenate" href="javascript:void(0);"
                  onClick="displayLogonBannerDialog()"> ${tenant_logonbanner_title}</a>
            </label>
         </div>
         <div id="logonMessageDiv">
            <a id="logonBannerTitle" class="hyphenate" href="javascript:void(0);"
               onClick="displayLogonBannerDialog()"> ${tenant_logonbanner_title}</a>
         </div>
         <input type="button" id="submit" class="btn btn-primary" onclick="submitentry()" value=${login}>
         <div id="progressBar" class="btn btn-primary" style="display:none">
            <span class="spinner spinner-inline"></span>
         </div>
      </div>
      <div id="particles-js"><canvas class="particles-js-canvas-el" style="width: 100%; height: 100%;"></canvas></div><div id="particles-js"></div>
   </form>
   <!-- IdP SingIn option -->
   <form id="idpSigninForm" class="login" autocomplete="off" method="post">
     <section class="title">
         <h1 class="welcome-msg subtitle">${wellcome_message}</h1>
         <h1 class="welcome-logout-msg subtitle">${signout_message}</h1>
         <span id="titleVmware">VMware<sup><b>&#174;</b></sup> vSphere</span>
         <span id="tenantBrand" style="display: none;">${tenant_brandname}</span>
         <h2 id="redirectToIdpMsg" class="subtitle">${redirect_message}</h2>
         <h2 id="redirectToIdpMsgNonDefaultIdp" class="subtitle">${redirect_message_nondefault}</h2>
         <div id="redirectToIdpSpinner">
             <span class="spinner spinner-lg" role="alert" aria-live="assertive"></span>
         </div>
     </section>
      <div class="login-group" id="idpLoginForm">
         <div id="userTextBoxOption">
            <label class="instruction" for="signInUsername">${signin_username}</label>
            <div id="signInUsernameError"></div>
            <input id="signInUsername" name="loginHint" class="username" type="text" placeholder="${username_placeholder}">
         </div>
         <div id="loginMsg">
            <div class="alert alert-danger" id="idpLoginMsgInfoID">
                <div class="alert-items">
                    <div class="alert-item static">
                        <div class="alert-icon-wrapper">
                            <clr-icon class="alert-icon" shape="exclamation-circle"></clr-icon>
                        </div>
                        <span class="alert-text" id="infoText"></span>
                    </div>
                </div>
            </div>
            <div id="idpLogonBannerID" class="checkbox logon-banner">
                <input id="idpLogonBannerCheckbox" type="checkbox" onclick="isIdpBannerChecked()">
                <label for="idpLogonBannerCheckbox">
                    <span id="agreementMsg">${iAgreeTo}</span>
                    <a id="idpLogonBannerHeading"
                       class="hyphenate"
                       href="javascript:void(0);"
                       onClick="displayLogonBannerDialog()">${tenant_logonbanner_title}</a>
                </label>
            </div>
            <div id="idpLogonMessageDiv">
                <a id="idpLogonBannerTitle"
                   class="hyphenate"
                   href="javascript:void(0);"
                   onClick="displayLogonBannerDialog()">${tenant_logonbanner_title}</a>
            </div>
         </div>
         <input type="hidden" name="providerId" id="providerIdInput" value="${vcenter_idp_id}"/>
         <button type="button"
                 id="nextBtn"
                 class="btn btn-primary"
                 onclick="validateUser()">${signin_next}</button>
         <button type="button"
                 id="signInBtn"
                 class="btn btn-primary"
                 onclick="redirectToIdp()">${signin_provider}</button>
         <button type="button"
                 id="signInBtnNonDefault"
                 class="btn btn-primary"
                 onclick="redirectToIdpNonDefault()">${signin_provider_nondefault}</button>
         <div class="center-align">
            <button type="button"
                    id="signInAnotherAccntBtn"
                    class="stack-action btn btn-link signin-btn-ink"
                    onclick="switchToTextFieldUsernameOption()">${signin_username}</button>
         </div>
         <div class="login-footer">
            <div>
               <button type="button" id="signInLocalBtn"
                       class="stack-action btn btn-link signin-btn-ink"
                       onclick="enableWebssoFlow()">${signin_local}</button>
            </div>
        </div>
      </div>
   </form>
</div>

<div id="dialogLogonBanner"></div>
<div id="footer" class="footer" style="display: none">
    <span id="downloadCIPRedirectToKBlinkBox" style="display:none">
       <span title="Warning">&#x26A0;&#xFE0F;</span>
       <a id="downloadCIPRedirectToKBlink" target="_blank" aria-live="polite"></a>
       <svg width="18" height="18" viewBox="0 0 24 24" style="vertical-align:text-bottom">
         <title>Open in new window</title>
         <path fill="#7B7E81" d="M14,3V5H17.59L7.76,14.83L9.17,16.24L19,6.41V10H21V3M19,19H5V5H12V3H5C3.89,3 3,3.9 3,5V19A2,2 0 0,0 5,21H19A2,2 0 0,0 21,19V12H19V19Z"></path>
       </svg>
    </span>
</div>
<div id="downloadCIPRedirectToKBforAriaLive" tab-index="-1" aria-live="polite"></div>
<div id="postForm"></div>

<div class="browser-validation-banner" style="visibility: hidden">
   <span class="validation-message-text">${unsupportedBrowserWarning}</span>
</div>

<script type="text/javascript">
   var titleVmwareDisplay = document.getElementById("titleVmware");
   var tenantBrandDisplay = document.getElementById("tenantBrand");
   if (isVCLogin()) {
      titleVmwareDisplay.style.display = "block";
      tenantBrandDisplay.style.display = "none";
   }
   else {
      titleVmwareDisplay.style.display = "none";
      tenantBrandDisplay.style.display = "block";
   }
</script>

<script type="text/javascript">
   if (isVCLogin() && !isBrowserSupportedVC()) {
      $(".browser-validation-banner").css("visibility", "visible");
   }
   if (isDiscovery && isDiscovery.trim() == "true") {
      var idpLogin = document.getElementById("idpSigninForm");
      var unpLogin = document.getElementById("loginForm");
      unpLogin.style.display = "none";
      idpLogin.style.display = "inherit";
   }
</script>
</body>
</html>
