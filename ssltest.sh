#!/bin/bash

# MIT License
# 
# Copyright (c) 2018 Dan Persons (dpersonsdev@gmail.com)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

VERSION="0.1"

usage() {
    echo "Usage: ${0##*/} [-hv] HOST"
    echo "  -h                  Print this help message"
    echo "  -v                  Print the version number"
    echo "  -f                  Full ssl certificate check"
    echo "  -i                  Accept untrusted certificates"
    echo "  -c CERTFILE         Set a CA certificate for verification"
    echo "  -o 'CURLOPTS'       Set additional options for curl"
    echo "  -p PORT             Set SSH port"
}

CURLCMD="curl -s"
SSHPORT="22"

while getopts ":vhfic:o:p:" o; do
    case "${o}" in
        v)
            echo putkey-$VERSION
            exit 0
            ;;
        h)
            usage
            exit 0
            ;;
        f)
            FULLCERTCHECK=1
            ;;
        i)
            CURLCMD="${CURLCMD} -k"
            ;;
        c)
            CERTFILE="${OPTARG}"
            CURLCMD="${CURLCMD} --cacert ${CERTFILE}"
            ;;
        o)
            CURLCMD="${CURLCMD} ${OPTARG}"
            ;;
        p)
            SSHPORT="${OPTARG}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

TARGETHOST="${1}"

# Check for color terminal:
if [ "$(tput colors)" -ge 256 ]; then
    DEFAULTCOLOR="\e[39m"
    REDCOLOR="\e[91m"
    GREENCOLOR="\e[92m"
    YELLOWCOLOR="\e[93m"
    CYANCOLOR="\e[96m"
else
    DEFAULTCOLOR=""
    REDCOLOR=""
    GREENCOLOR=""
    YELLOWCOLOR=""
    CYANCOLOR=""
fi


checksslconf() {
    echo
    echo -e "${CYANCOLOR}=== Web server info for ${TARGETHOST} ===${DEFAULTCOLOR}"
    # Print web server info
    SERVERTYPE=$(${CURLCMD} -I "https://${TARGETHOST}" | grep "^Server: ")
    if [ -n "$SERVERTYPE" ]; then
        echo "$SERVERTYPE"
    else
        echo -e "[${YELLOWCOLOR}---${DEFAULTCOLOR}] Web server type not found.."
    fi
    echo

    # Check for unsecured HTTP
    HTTPMOVED=$(${CURLCMD} -I "http://${TARGETHOST}" | grep "^HTTP" | grep "301 Moved Permanently")
    HTTPFOUND=$(${CURLCMD} -I "http://${TARGETHOST}" | grep "^HTTP" | grep "302 Found")
    if [ -n "$HTTPMOVED" ]; then
        echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] HTTP redirects on port 80."
    elif [ -n "$HTTPFOUND" ]; then
        echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] Unsecured HTTP is enabled!"
    else
        echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] HTTP is not enabled on port 80."
    fi

    HTTP8KFOUND=$(${CURLCMD} -I "http://${TARGETHOST}:8000" | grep "^HTTP" | grep "302 Found")
    if [ -n "$HTTP8KFOUND" ]; then
        echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] Unsecured HTTP is enabled on port 8000!"
    else
        echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] HTTP is not enabled on port 8000."
    fi
    # Check for HTTPS
    HTTPSFOUND=$(${CURLCMD} -I "https://${TARGETHOST}" | grep "^HTTP")
    if [ -n "$HTTPSFOUND" ]; then
        echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] HTTPS is enabled."

        # Check supported SSL/TLS protocols
        echo
        echo -e "${CYANCOLOR}=== Checking supported HTTPS protocols ===${DEFAULTCOLOR}"
        ISSSLV2=$(${CURLCMD} --sslv2 -I "https://${TARGETHOST}" | grep "^HTTP")
        ISSSLV3=$(${CURLCMD} --sslv3 -I "https://${TARGETHOST}" | grep "^HTTP")
        ISTLSV10=$(${CURLCMD} --tlsv1.0 -I "https://${TARGETHOST}" | grep "^HTTP")
        ISTLSV11=$(${CURLCMD} --tlsv1.1 -I "https://${TARGETHOST}" | grep "^HTTP")
        ISTLSV12=$(${CURLCMD} --tlsv1.2 -I "https://${TARGETHOST}" | grep "^HTTP")
        if [ -n "$ISSSLV2" ]; then
            echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] SSLv2 is enabled!"
        else
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] SSLv2 is disabled."
        fi
        if [ -n "$ISSSLV3" ]; then
            echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] SSLv3 is enabled!"
        else
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] SSLv3 is disabled."
        fi
        if [ -n "$ISTLSV10" ]; then
            echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] TLSv1.0 is enabled!"
        else
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] TLSv1.0 is disabled."
        fi
        if [ -n "$ISTLSV11" ]; then
            echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] TLSv1.1 is enabled!"
        else
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] TLSv1.1 is disabled."
        fi
        if [ -n "$ISTLSV12" ]; then
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] TLSv1.2 is enabled."
        else
            echo -e "[${YELLOWCOLOR}---${DEFAULTCOLOR}] TLSv1.2 is disabled."
        fi

        echo
        echo -e "${CYANCOLOR}=== Checking header attributes ===${DEFAULTCOLOR}"
        # Check for HSTS http header
        HSTSHEADER=$(${CURLCMD} -I "https://${TARGETHOST}" | grep "^Strict")
        if [ -n "$HSTSHEADER" ]; then
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] Strict transport security header enabled."
        else
            echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] Strict transport security header not found!"
        fi

        # Check content embedding protections
        XFOPTSSAME=$(${CURLCMD} -I "https://${TARGETHOST}" | grep "^X-Frame-Options" | grep "SAMEORIGIN")
        XFOPTSDENY=$(${CURLCMD} -I "https://${TARGETHOST}" | grep "^X-Frame-Options" | grep "DENY")
        if [ -n "$XFOPTSSAME" ];
        then
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] Content embedding protections enabled."
        elif [ -n "$XFOPTSDENY" ];
        then
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] Content embedding protections enabled."
        else
            echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] Content embedding protections not found!"
        fi

        # Check ciphers with nmap
        echo
        echo -e "${CYANCOLOR}=== Checking key lengths and supported symmetric ciphers ===${DEFAULTCOLOR}"
        nmap --script ssl-enum-ciphers -p 443 "${TARGETHOST}"
        echo

    else
        echo -e "[${YELLOWCOLOR}---${DEFAULTCOLOR}] HTTPS is not enabled on port 443."
    fi
    echo
}

checksslcert() {
    # Check server certificate
    echo
    echo -e "${CYANCOLOR}=== Checking server certificate ===${DEFAULTCOLOR}"
    echo -e "${CYANCOLOR}= Server public key: 4096 bits recommended, 2048 bits minimum =${DEFAULTCOLOR}"
    if [ ${CERTFILE} ]; then
        CERTINFO=$(openssl s_client -cert "${CERTFILE}" -showcerts -connect "${TARGETHOST}:443" -verify_hostname "${TARGETHOST}" |& grep -e "^Server public key" -e "^depth=" -e "^verify error:" -e "^verify return:" -e "Verify return code:")
    else
        CERTINFO=$(openssl s_client -showcerts -connect "${TARGETHOST}:443" -verify_hostname "${TARGETHOST}" |& grep -e "^Server public key" -e "^depth=" -e "^verify error:" -e "^verify return:" -e "Verify return code:")
    fi
    if [ -n "$CERTINFO" ]; then
        echo "$CERTINFO"
    else
        echo -e "[${YELLOWCOLOR}---${DEFAULTCOLOR}] No server public key."
    fi

    # Check DH key length
    echo
    echo -e "${CYANCOLOR}= Diffie-Hellman temp key: should be no shorter than public key =${DEFAULTCOLOR}"
    if [ ${CERTFILE} ]; then
        DHTEMPKEY=$(openssl s_client -cert "${CERTFILE}" -connect "${TARGETHOST}:443" -cipher "EDH" |& grep "^Server Temp Key")
    else
        DHTEMPKEY=$(openssl s_client -connect "${TARGETHOST}:443" -cipher "EDH" |& grep "^Server Temp Key")
    fi
    if [ -n "$DHTEMPKEY" ]; then
        echo "$DHTEMPKEY"
    else
        echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] No DH temp key."
    fi
    echo
}

checksshconf() {
    echo
    echo -e "${CYANCOLOR}=== Checking SSH protocol information ===${DEFAULTCOLOR}"
    NOSSH=$(ssh -v -o PasswordAuthentication=no -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${SSHPORT}" "user@${TARGETHOST}" |& grep "^ssh: connect to host ${TARGETHOST} port ${SSHPORT}: Connection refused")
    if [ -n "$NOSSH" ]; then
        echo -e "[${YELLOWCOLOR}---${DEFAULTCOLOR}] SSH is disabled on port ${SSHPORT}."
    else
        echo -e "${CYANCOLOR}= Checking SSH version 1 =${DEFAULTCOLOR}"
        NOSSHV1=$(ssh -1v -o PasswordAuthentication=no -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${SSHPORT}" "user@${TARGETHOST}" |& grep "^Protocol major versions differ")
        if [ -n "$NOSSHV1" ]; then
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] SSH version 1 is disabled."
        else
            echo -e "[${REDCOLOR}!!!${DEFAULTCOLOR}] SSH version 1 is enabled!"
        fi
        echo
        echo -e "${CYANCOLOR}= Checking SSH version 2 =${DEFAULTCOLOR}"
        SSHV2=$(ssh -2 -v -o PasswordAuthentication=no -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${SSHPORT}" "user@${TARGETHOST}" |& grep -o -e "Remote protocol version .*$" -e "Server host key: .*$" -e "Authentications that can continue: .*$")
        if [ -n "$SSHV2" ]; then
            echo -e "[${GREENCOLOR}...${DEFAULTCOLOR}] SSH version 2 is enabled."
            echo
            echo "$SSHV2"
        else
            echo -e "[${YELLOWCOLOR}---${DEFAULTCOLOR}] SSH version 2 is disabled."
        fi
    fi
    echo
}

checksslconf
if [ $FULLCERTCHECK ]; then
    checksslcert
fi
checksshconf
