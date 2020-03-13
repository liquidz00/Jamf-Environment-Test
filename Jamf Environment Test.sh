#!/bin/bash
####################################################################################################
#
# Copyright (c) 2020, Jamf, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
####################################################################################################

# written by Daniel MacLaughlin and Oliver Lindsey, March 2020
# https://github.com/jamf/Jamf-Environment-Test

#########################################################################################
# General Information
#########################################################################################
# This script is the raw version of the associated application
# it is designed to query a list of Apple and Jamf Urls to connectivity errors


# Setup some vars

runProxySettings=true
runNetworkChecks=true
runAdditionalChecks=true

#Apple URLS from https://support.apple.com/en-us/HT210060
#Format is url,port,protocol,category
APPLE_URL_ARRAY=(
  #Device Setup
  "albert.apple.com,443,TCP,Device Setup Hosts"
  "captive.apple.com,80,TCP"
  "captive.apple.com,443,TCP"
  "gs.apple.com,443,TCP"
  "humb.apple.com,443,TCP"
  "static.ips.apple.com,80,TCP"
  "static.ips.apple.com,443,TCP"
  "tbsc.apple.com,443,TCP"
  "time-ios.apple.com,123,UDP"
  "time.apple.com,123,UDP"
  "time-macos.apple.com,123,UDP"

  #Device Apple Push Notifications
  "courier.push.apple.com,5223,TCP,Device Push Notification Hosts"
  "courier.push.apple.com,443,TCP"

  #On-Prem Jamf Pro Push Notification Hosts
  "gateway.push.apple.com,2195,TCP,On-Prem Jamf Pro Apple Push - Binary Protocol"
  "feedback.push.apple.com,2196,TCP"

  #On-Prem Jamf Pro Push Notification Hosts - HTTP/2 Provider 
  "api.push.apple.com,443,TCP,On-Prem Jamf Pro Apple Push  - HTTP/2 Provider"
  "api.push.apple.com,2197,TCP"
  
  #Device Management
  "gdmf.apple.com,443,TCP,Device Management and Enrollment"
  "deviceenrollment.apple.com,443,TCP"
  "deviceservices-external.apple.com,443,TCP"
  "identity.apple.com,443,TCP"
  "iprofiles.apple.com,443,TCP"
  "mdmenrollment.apple.com,443,TCP"
  "vpp.itunes.apple.com,443,TCP"
  
  #Software updates
  "appldnld.apple.com,80,TCP,Software Updates Hosts"
  "gg.apple.com,80,TCP"
  "gg.apple.com,443,TCP"
  "gnf-mdn.apple.com,443,TCP"
  "gnf-mr.apple.com,443,TCP"
  "gs.apple.com,80,TCP"
  "gs.apple.com,443,TCP"
  "ig.apple.com,443,TCP"
  "mesu.apple.com,80,TCP"
  "mesu.apple.com,443,TCP"
  "ns.itunes.apple.com,443,TCP"
  "oscdn.apple.com,80,TCP"
  "oscdn.apple.com,443,TCP"
  "osrecovery.apple.com,80,TCP"
  "osrecovery.apple.com,443,TCP"
  "skl.apple.com,443,TCP"
  "swcdn.apple.com,80,TCP"
  "swdist.apple.com,443,TCP"
  "swdownload.apple.com,80,TCP"
  "swdownload.apple.com,443,TCP"
  "swpost.apple.com,80,TCP"
  "swscan.apple.com,443,TCP"
  "updates-http.cdn-apple.com,80,TCP"
# This one doesn't seem to exist... "updates.apple.com,443,TCP"
  "updates.cdn-apple.com,443,TCP"
  "xp.apple.com,443,TCP"

  #App Store
  "itunes.apple.com,443,TCP,Apple App Store Hosts"
  "ns.itunes.apple.com,443,TCP"
  "init.itunes.apple.com,443,TCP"
  "apps.apple.com,443,TCP"
  "mzstatic.com,443,TCP"
  "ppq.apple.com,443,TCP"
  
  #Content Caching
  "lcdn-registration.apple.com,443,TCP,Content Caching"
  
  #Certificate validation
  "crl.apple.com,80,TCP,Certificate Validation Hosting"
  "crl.entrust.net,80,TCP"
  "crl3.digicert.com,80,TCP"
  "crl4.digicert.com,80,TCP"
  "ocsp.apple.com,80,TCP"
  "ocsp.digicert.com,80,TCP"
  "ocsp.entrust.net,80,TCP"
  "ocsp.verisign.net,80,TCP"

  #Jamf Hosts
  "www.jamfcloud.com,443,TCP,Jamf Services"
  "use1-jcdsdownloads.services.jamfcloud.com,443,TCP"
  "use1-jcds.services.jamfcloud.com,443,TCP"  
)

NL=$'\n'

####################################################################################################
# 
# FUNCTIONS
#
####################################################################################################


####################################################################################################
# FILE FUNCTION
###
# Create a file into which we will save the Report ###
function CreateEmptyReportFile () {
  echo "[step] Creating the report file "
  CURRENT_USER=$(/bin/ls -l /dev/console | awk '/ / { print $3 }')
  FOLDER="/Users/Shared"
  if [[ ! -d "$FOLDER" ]]; then
    FOLDER="${HOME}/Desktop"
    if [[ ! -d "$FOLDER" ]]; then
      echo "[error] I wasn't able to locate the /Users/Shared or your desktop folder : \"$FOLDER\""
      exit 1
    fi
  fi
  REPORT_FILE_NAME="Jamf Environment Test Results [$(/bin/date +"%Y-%m-%dT%H%M")].html"
  REPORT_PATH="${FOLDER}/${REPORT_FILE_NAME}"
  touch "$REPORT_PATH"
  if [[ ! -f "$REPORT_PATH" ]]; then
    echo "[error] I wasn't able to create a results file : \"$REPORT_PATH\""
    exit 1
  fi
}


####################################################################################################
# GET INFO FUNCTIONS
###

#### Local macOS Additional Network information ###
function CalculateProxyInfoTableRows () {

  echo "[step] Getting proxy config info..."
  PROXY_INFO_TABLE_ROWS=''

  #Build Array of network interfaces, replacing a " " with "_" it will be removed during the Loop
  ALL_INTERFACES=$(/usr/sbin/networksetup -listallnetworkservices | /usr/bin/tail -n +2 | sed -e 's/ /_/g')
  
  for INTERFACE in $ALL_INTERFACES;
  do
    CURRENT_INTERFACE=$(echo $INTERFACE | sed -e 's/_/ /g') # Replace _ with a space for readability
    echo "  > Checking proxy on ${CURRENT_INTERFACE}"
    AUTO_PROXY=$(/usr/sbin/networksetup -getproxyautodiscovery "$CURRENT_INTERFACE")
    AUTO_PROXY_URL=$(/usr/sbin/networksetup -getautoproxyurl "$CURRENT_INTERFACE")
    WEB_PROXY=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE")
    SECURE_WEB_PROXY=$(/usr/sbin/networksetup -getsecurewebproxy "$CURRENT_INTERFACE")
    FTP_PROXY=$(/usr/sbin/networksetup -getftpproxy "$CURRENT_INTERFACE")
    SOCKS_PROXY=$(/usr/sbin/networksetup -getsocksfirewallproxy "$CURRENT_INTERFACE")
    STREAMING_PROXY=$(/usr/sbin/networksetup -getstreamingproxy "$CURRENT_INTERFACE")
    GOPHER_PROXY=$(/usr/sbin/networksetup -getgopherproxy "$CURRENT_INTERFACE")
    PROXY_BYPASS_DOMAINS=$(/usr/sbin/networksetup -getproxybypassdomains "$CURRENT_INTERFACE")
    PROXY_BYPASS_DOMAINS="${PROXY_BYPASS_DOMAINS//$'\n'/<br />}"  # Domain lists can have newlines... convert to html <br>
    DNS_SERVERS=$(/usr/sbin/networksetup -getdnsservers "$CURRENT_INTERFACE")
    SEARCH_DOMAINS=$(/usr/sbin/networksetup -getsearchdomains "$CURRENT_INTERFACE")
    if [[ $AUTO_PROXY == *"Auto Proxy Discovery: Off"* ]]; then
      AUTO_PROXY_STATUS='<td style="color: green;">Off</td>'
      else
      AUTO_PROXY_STATUS='<td style="red">On</td>'
    fi
    if [[ $AUTO_PROXY_URL == *"Enabled: No"* ]]; then
      AUTO_PROXY_URL_STATUS='<td style="color: green;">Off</td>'
      else
      AUTO_PROXY_URL_STATUS=$(/usr/sbin/networksetup -getautoproxyurl "$CURRENT_INTERFACE" | awk 'NR==1' | awk '{print $2}')
      AUTO_PROXY_URL_STATUS="<td style=\"color: red\">${AUTO_PROXY_URL_STATUS}</td>"
    fi
    if [[ $WEB_PROXY == *"Enabled: No"* ]]; then
      WEB_PROXY_STATUS='<td style="color: green;">Off</td>'
      else
      WEB_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==2'| awk '{print $2}')
      WEB_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==3'| awk '{print $2}')
      WEB_PROXY_STATUS="<td style=\"color: red\">${WEB_PROXY_URL}:${WEB_PROXY_PORT}</td>"
    fi
    if [[ $SECURE_WEB_PROXY == *"Enabled: No"* ]]; then
      SECURE_WEB_PROXY_STATUS='<td style="color: green;">Off</td>'
      else
      SECURE_WEB_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==2'| awk '{print $2}')
      SECURE_WEB_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==3'| awk '{print $2}')
      SECURE_WEB_PROXY_STATUS="<td style=\"color: red\">${SECURE_WEB_PROXY_URL}:${SECURE_WEB_PROXY_PORT}</td>"
    fi
    if [[ $FTP_PROXY == *"Enabled: No"* ]]; then
      FTP_PROXY_STATUS='<td style="color: green;">Off</td>'
      else
      FTP_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==2'| awk '{print $2}')
      FTP_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==3'| awk '{print $2}')
      FTP_PROXY_STATUS="<td style=\"color: red\">${FTP_PROXY_URL}:${FTP_PROXY_PORT}</td>"
    fi
    if [[ $SOCKS_PROXY == *"Enabled: No"* ]]; then
      SOCKS_PROXY_STATUS='<td style="color: green;">Off</td>'
      else
      SOCKS_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==2'| awk '{print $2}')
      SOCKS_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==3'| awk '{print $2}')
      SOCKS_PROXY_STATUS="<td style=\"color: red\">${SOCKS_PROXY_URL}:${SOCKS_PROXY_PORT}</td>"
    fi
    if [[ $STREAMING_PROXY == *"Enabled: No"* ]]; then
      STREAMING_PROXY_STATUS='<td style="color: green;">Off</td>'
      else
      STREAMING_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==2'| awk '{print $2}')
      STREAMING_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==3'| awk '{print $2}')
      STREAMING_PROXY_STATUS="<td style=\"color: red\">${STREAMING_PROXY_URL}:${STREAMING_PROXY_PORT}</td>"
    fi
    if [[ $GOPHER_PROXY == *"Enabled: No"* ]]; then
      GOPHER_PROXY_STATUS='<td style="color: green;">Off</td>'
      else
      GOPHER_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==2'| awk '{print $2}')
      GOPHER_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "$CURRENT_INTERFACE" | awk 'NR==3'| awk '{print $2}')
      GOPHER_PROXY_STATUS="<td style=\"color: red\">${GOPHER_PROXY_URL}:${GOPHER_PROXY_PORT}</td>"
    fi
    if [[ $PROXY_BYPASS_DOMAINS == *"There aren't any bypass domains set"* ]]; then
      PROXY_BYPASS_DOMAINS_STATUS='<td style="color: green;">Off</td>'
      else
      PROXY_BYPASS_DOMAINS_STATUS="<td style=\"color: black\">${PROXY_BYPASS_DOMAINS}</td>"
    fi
    if [[ $DNS_SERVERS == *"There aren't any DNS Servers set"* ]]; then
      DNS_SERVERS_STATUS='<td style="color: green;">Off</td>'
      else
      DNS_SERVERS_STATUS="<td style=\"color: red\">${DNS_SERVERS}</td>"
    fi
    if [[ $SEARCH_DOMAINS == *"There aren't any Search Domains set"* ]]; then
      SEARCH_DOMAINS_STATUS='<td style="color: green;">Off</td>'
      else
      SEARCH_DOMAINS_STATUS="<td style=\"color: red\">${SEARCH_DOMAINS}</td>"
    fi
    PROXY_INFO_TABLE_ROWS+="      <tr>
        <td>${CURRENT_INTERFACE}</td>
        ${AUTO_PROXY_STATUS}
        ${AUTO_PROXY_URL_STATUS}
        ${WEB_PROXY_STATUS}
        ${SECURE_WEB_PROXY_STATUS}
        ${FTP_PROXY_STATUS}
        ${SOCKS_PROXY_STATUS}
        ${STREAMING_PROXY_STATUS}
        ${GOPHER_PROXY_STATUS}
        ${PROXY_BYPASS_DOMAINS_STATUS}
        ${DNS_SERVERS_STATUS}
        ${SEARCH_DOMAINS_STATUS}
      </tr>"
    done
}


### Get URL Connection Status ###
function CalculateHostInfoTables () {
  echo "[step] Checking Apple Hosts..."
  lastCategory="zzzNone"  # Some fake category so we recognize that the first host is the start of a new category
  firstServer="yes"       # Flag for the first host so we don't try to close the preceding table -- there won't be one. 
  HOST_TEST_TABLES=''    # This is the var we will insert into the HTML
  for SERVER in "${APPLE_URL_ARRAY[@]}"; do
    #split the URL info fields
    URL=$(echo $SERVER | cut -d ',' -f1)
    PORT=$(echo $SERVER | cut -d ',' -f2)
    PROTOCOL=$(echo $SERVER | cut -d ',' -f3)
    CATEGORY=$(echo $SERVER | cut -d ',' -f4)
    # We have categories of hosts... enrollment, software update, etc. We'll put them in separate tables
    # If the category for this host is different than the last one and is not blank...
    if [[ "$lastCategory" != "$CATEGORY" ]] && [[ ! -z "$CATEGORY" ]]; then
      # If this is not the first server, close up the table from the previous category before moving on to the next. 
      echo "Starting Category : $CATEGORY"
      if [[ "$firstServer" != "yes" ]]; then
        #We've already started the table html so no need to do it again.  
        HOST_TEST_TABLES+="    </table>${NL}"
      fi
      firstServer="no"
      lastCategory="$CATEGORY"
      HOST_TEST_TABLES+="    <h3>${CATEGORY}</h3>${NL}"
      HOST_TEST_TABLES+="    <table class=\"tg\">${NL}"
      HOST_TEST_TABLES+="      <tr><th width=\"50%\">URL</th><th width=\"10%\">Port</th><th width=\"10%\">Protocol</th><th width=\"10%\">Accesible</th><th width=\"20%\">SSL Error</th></tr>${NL}"
    fi # End of table start and end logic.

    echo "  > Checking connectivity to : $URL"

    # Now print the info for this host...
    # Set NC flags for TCP vs UDP
    if [[ $PROTOCOL == "TCP" ]]; then
#       AVAILBILITY=$(/usr/bin/nc -z -G 1 $URL $PORT 2>&1)
# nc -v -z -w 3 itunes.apple.com 443 &> /dev/null && echo "Online" || echo "Offline"
        # -- run command if fails to complete in 3 secs assume host unreachable --
        ( nc -z -w 3 ${URL} ${PORT} >/dev/null 2>&1 ) & pid=$!
        ( sleep 3 && kill -HUP $pid ) 2>/dev/null & watcher=$!
        if wait $pid 2>/dev/null; then
            pkill -HUP -P $watcher
            wait $watcher
            # -- command finished (we have connection) --
            AVAILBILITY="succeeded"
        else
            # -- command failed (no connection) --
            AVAILBILITY=""
        fi
    else    
#       AVAILBILITY=$(/usr/bin/nc -zu -w 1 $URL $PORT 2>&1)
        # -- run command if fails to complete in 3 secs assume host unreachable --
        ( nc -zu -w 3 ${URL} ${PORT} >/dev/null 2>&1 ) & pid=$!
        ( sleep 3 && kill -HUP $pid ) 2>/dev/null & watcher=$!
        if wait $pid 2>/dev/null; then
            pkill -HUP -P $watcher
            wait $watcher
            # -- command finished (we have connection) --
            AVAILBILITY="succeeded"
        else
            # -- command failed (no connection) --
            AVAILBILITY=""
        fi
    fi

    if [[ "$AVAILBILITY" =~ "succeeded" ]]; then
      AVAILBILITY_STATUS='<td style="color: green;">Available</td>'
      #Test for SSL Inspection
      if [[ $PORT == "80" ]]; then
        #http traffic no ssl inspection issues
        SSL_STATUS='<td style="color: green;">N/A</td>'
      else
        if [[ $PROTOCOL == "TCP" ]]; then                
          # && [[ $PORT == "443" ]]
          # shopt -s extglob
          certSubject=$(echo | /usr/bin/openssl s_client -showcerts -connect "${URL}:${PORT}" 2>/dev/null)
          if echo "$certSubject" | grep --silent "no peer certificate available"; then
            SSL_STATUS="<td>None</td>"
          else
            certSubject=$(echo "$certSubject" | /usr/bin/openssl x509 -noout -subject | sed 's|subject= /CN=||')
            if [[ -z "$certSubject" ]]; then
              SSL_STATUS="<td><mark>Certificate Unreadable</mark></td>"
            else
              SSL_STATUS="<td style=\"color: red;\">Unexpected Certificate: $certSubject</td>"
              case "$URL" in
                *apple.com*)
                  [[ $certSubject =~ "Apple Inc." ]] && SSL_STATUS="<td style=\"color: green;\">OK</td>"
                  [[ $certSubject =~ "Akamai Technologies" ]] && SSL_STATUS="<td style=\"color: green;\">OK</td>"
                  ;;
                *services.jamfcloud.com*)
                  [[ $certSubject =~ "*.services.jamfcloud.com" ]] && SSL_STATUS="<td style=\"color: green;\">OK</td>"
                  ;;
                *jamfcloud.com*)
                  [[ $certSubject =~ "*.jamfcloud.com" ]] && SSL_STATUS="<td style=\"color: green;\">OK</td>"
                  ;;
                *)
                  SSL_STATUS='<td style="color: red;"><mark>Unhandled Certificate: $certSubject</mark></td>'        
              esac
            fi # if [[ -z "$certSubject" ]]; then
          fi # if [[ echo "$certSubject" | grep "no peer certificate available" ]]; then
        else
          SSL_STATUS='<td style="color: green;">N/A</td>'
        fi
      fi
    else
      # nc did not connect. There is no point in trying the SSL cert subject test. 
      AVAILBILITY_STATUS='<td style="color: red;">Unavailable</td>'
      SSL_STATUS='<td style="color: black;">Not checked</td>'
    fi
    # Done. Stick the row of info into the HTML var...
    HOST_TEST_TABLES+="        <tr><td>$URL</td><td>$PORT</td><td>$PROTOCOL</td>${AVAILBILITY_STATUS}${SSL_STATUS}</tr>${NL}"
  done
  # Close up the html for the final table
  HOST_TEST_TABLES+="    </table>${NL}"
}

# ######################################################################
#  END OF NETWORK TESTS
# ######################################################################


# ######################################################################
#  REPORT
# ######################################################################


function GenerateReportHTML () {
/bin/cat << EOF >> "$REPORT_PATH"
<html>
  <head>  
    <style type="text/css">
      body { background-color:#444444;font-family:Helvetica,Arial,sans-serif;margin:20px; }
      h1 { margin-top:1em;margin-bottom:0.2em;color:#9eb8d5 }
      h2 { margin-top:1em;margin-bottom:0.2em;color:#37bb9a }
      h3 { margin-top:0.8em;margin-bottom:0.2em;color:#e8573f }
      p { margin-top:0.2em;margin-bottom:0.2em;padding: 0 0 0 1px;color:white }
      .tg    { border-collapse:collapse;border-spacing:0;border-color:#9ABAD9;width: 900px; }
      .tg td { font-family:monospace;font-size:14px;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#444;background-color:#EBF5FF; }
      .tg th { font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#fff;background-color:#409cff; }
      .tg .tg-0lax { text-align:left;vertical-align:top }
      .tg2    { border-collapse:collapse;border-spacing:0;border-color:#9ABAD9;width: auto; }
      .tg2 td { font-family:monospace;font-size:14px;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#444;background-color:#EBF5FF;vertical-align: top; }
      .tg2 th { font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#fff;background-color:#409cff; }
      .bottom-table { margin-top: 1cm; border: none; border-spacing: 20px 0;}
      a:link { color: white;}
      a:visited { color: lightgreen;}
      a:hover { color: hotpink;}
      a:active { color: blue;}
    </style>
  </head>

  <body>
    <a href="https://www.jamf.com">
      <img src="data:image/png;base64,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" height=50px style="margin-bottom: 1.0em"/>
    </a>
    <h1>Environment Tests</h1>
    <p>Date: $(/bin/date +"%a %d %b %Y %R")</p>

    <h2>Client Details</h2>
    <p>Computer Name: $(/usr/sbin/scutil --get ComputerName)</p>
    <p>macOS Model: $(/usr/sbin/sysctl -n hw.model)</p>
    <p>macOS Version: $(/usr/bin/sw_vers -productVersion), $(/usr/bin/awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | /usr/bin/awk -F 'macOS ' '{print $NF}' | /usr/bin/tr -d '\\') build $(/usr/bin/sw_vers -buildVersion)</p>

    <h2>Client Network Details</h2>
    <p>Public IP: $(/usr/bin/AssetCacheLocatorUtil 2>&1 | /usr/bin/grep "public IP address is" | awk 'NR==1{print $NF}' | /usr/bin/sed 's/\.$//')</p>
    <p>Local IP: $(echo "$sysProfilerNetworkData" | /usr/bin/grep "IPv4 Addresses:" | /usr/bin/awk 'NR==1{print $NF}')</p>
    <p>Primary Network Interface: $( echo "$sysProfilerNetworkData" | /usr/bin/grep -B 5 "IPv4 Addresses:" | /usr/bin/grep "Type: " | /usr/bin/awk 'NR==1{print $NF}')</p>
    <p>WIFI Interface: $(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/,/Ethernet/' | awk 'NR==2' | cut -d " " -f 2)</p>
EOF

if [[ $runProxySettings = true ]]; then
/bin/cat << EOF >> "$REPORT_PATH"  
    <h2>Proxy Settings</h2>
    <table class="tg">
      <tr>
        <th>Interface</th>
        <th>Auto Proxy Discovery</th>
        <th>Auto Proxy Config</th>
        <th>Web Proxy</th>
        <th>Secure Web Proxy</th>
        <th>FTP Proxy</th>
        <th>Socks Proxy</th>
        <th>Streaming Proxy</th>
        <th>Gopher Proxy</th>
        <th>Proxy Bypass Domains</th>
        <th>Static DNS Servers</th>
        <th>Static Search Domains</th>
      </tr>
      ${PROXY_INFO_TABLE_ROWS}
    </table>
EOF
fi

if [[ $runNetworkChecks = true  ]]; then
/bin/cat << EOF >> "$REPORT_PATH"  
    <p />
    <h2>Server Connectivity Tests</h2>
    <p>Network access to the following hostnames are required for enrolling, installing, restoring or updating Apple OSs. We will test the ability to reach these services from this device. We will also check SSL certificate subjects to see if any proxies may be replacing them. Many Apple services use certificate pinning to prevent SSL interception.</p>
    <p>
      <u>References:</u> <a href="https://support.apple.com/en-us/HT210060">Use Apple products on enterprise networks</a> / <a href="https://support.apple.com/en-us/HT201999">About macOS, iOS, and iTunes server host connections</a>
    </p>
${HOST_TEST_TABLES}
EOF
fi

if [[ $runAdditionalChecks = true ]]; then
/bin/cat << EOF >> "$REPORT_PATH"  
    <h2>Other Information and Settings</h2>
    <table class="tg2">
      <tr>
        <th>Test</th>
        <th>Answer</th>
        <th>Follow-up</th>
      </tr>
      <tr>
        <td>Content Cache</td>
        <td>$(none "$(/usr/bin/AssetCacheLocatorUtil 2>&1 | /usr/bin/grep "guid" | /usr/bin/awk '{print $4}' | /usr/bin/awk -F: '{print $1}' | /usr/bin/sort -u)" "none")</td>
        <td>If none is available, discuss how Apple content caching improves user experience and reduces WAN traffic.</td>
      </tr>
      <tr>
        <td>APNS apsctl Status</td>
        <td>$(none "$(/System/Library/PrivateFrameworks/ApplePushService.framework/apsctl status | /usr/bin/grep "connected to server hostname:")" "Unknown" "Connected")</td>
        <td>Apple Push Notifications should be accessible.</td>
      </tr>
      <tr>
        <td>Launch Daemons</td>
        <td>$( launchctl list | grep -v com.apple. | cut -f3 | sed 's|$|<br>|g' | awk NR\>1 )</td>
        <td>Verify that all are expected and needed.</td>
      </tr>
      <tr>
        <td>Third-Party System Extensions</td>
        <td>$( kextstat | grep -v com.apple | awk '{print $6}' | sed 's|$|<br>|g' | awk NR\>1 )</td>
        <td>Discuss upgrades or replacement solutions that decrease reliance on kernel extensions.</td>
      </tr>
      <tr>
        <td>Active Directory Domain</td>
        <td>$(none "$(/usr/sbin/dsconfigad -show | /usr/bin/grep 'Active Directory Domain' | /usr/bin/awk '{print $5}')" "none")</td>
        <td>If binding is used, discuss modern authentication and no-bind approaches.</td>
      </tr>
    </table>
EOF
fi

/bin/cat << EOF >> "$REPORT_PATH"  
    <table class="bottom-table">
      <tr>
        <td style=“padding-right:15px;”>
          <img src="data:image/png;base64,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" />
        </td>
        <td style=color:white; >
          Want to share this report? Use the share button in the upper-right corner of your Safari window or email the saved file (${REPORT_PATH}">).
        </td>
      </tr>
    </table>
  </body>
</html>
EOF

# Remove comments from HTML
# cat "$REPORT_PATH" | sed -i -e :a -re 's/<!--.*?-->//g;/<!--/N;//ba' > "$REPORT_PATH"
# sed -i '' -e :a -e 's/<!--.*?-->//g;/<!--/N;//ba' "$REPORT_PATH"
}


function none () {
  # If $1 has no value, return $2, which is something like "n/a" or "none".
  # > If nothing is specified for $2, "none" is used. 
  # If $1 has a value, it is returned unless an optional third value is passed,
  #  in which case $3 is returned instead of $1.
  # Seems nicer than just showing a blank value when a test had no result. 
  text=$1
  [[ -z "$2" ]] && noValue_return="none" || noValue_return="$2"
  [[ -z "$3" ]] && return="$text" || return="$3"
  [[ -z "$text" ]] && echo "$2" || echo "$return"
}

### MAIN
echo "[start] Starting tests"
echo "[step] Requesting network interface info..."
sysProfilerNetworkData=$(/usr/sbin/system_profiler SPNetworkDataType 2> /dev/null)


CreateEmptyReportFile
[[ $runProxySettings = true ]] && CalculateProxyInfoTableRows
[[ $runNetworkChecks = true ]] && CalculateHostInfoTables
GenerateReportHTML
open -a "Safari" "$REPORT_PATH"
echo '[Done] Environment Checks Complete'
echo "[acknowledgement] Host listings provided by Apple, Inc. (Public KB)"
echo "[acknowledgement] Icon plane by Juan Garces from the Noun Project, licensed under Create Commons (cc)"




