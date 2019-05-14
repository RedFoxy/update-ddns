#!/bin/bash
###################################################################
#                                                                 #
#                      Aggiorna Dynamic DNS                       #
#                       v1.1.1 14/05/2019                         #
#               by Massimo "RedFoxy Darrest" Cicciò               #
#                     https://www.redfoxy.it                      #
#               https://twitter.com/RedFoxy_Darrest               #
#                                                                 #
###################################################################

#------------------------------------------------------------------
# Default values
#------------------------------------------------------------------

# 1 = Active - 0 = Disabled
def_debug=1
def_send_mail=1
def_log_change=1
def_log_no_change=0

#------------------------------------------------------------------

if [ ! $1 ] || [ ! -f $1 ]; then
	me=`basename "$0"`
	echo "Error! A config file must be specified.";
	echo "Usage: $me /etc/update-ddns.conf";
	exit 2;
else
	. $1
fi

if [ ! $username ] || [ ! $password ] || [ ! $dhost ] || [ ! $updatedd ]; then
	echo "Error: One or more informations are not present.";
	exit 2;
else
	if [ "${updatedd}" = "1" ]; then
		if [ ! $provider ]; then
			echo "Error: A provider must be specified.";
			exit 2;
		fi
	else
		if [ ! "${curl_url}" ]; then
			echo "Error: A valid url must be specified.";
			exit 2;
		fi
	fi
fi

if [ ! "${mail_notify}" ] || [ ! "${mail_subject}" ]; then
	send_mail=0;
fi


log_file="/var/log/dyndns-${dhost}.log";
cache_old_ip="/tmp/dyndns-ip-${dhost}";

debug=${debug:-$def_debug};
send_mail=${send_mail:-$def_send_mail};
log_change=${log_change:-$def_log_change};
log_no_change=${log_no_change:-$def_log_no_change};
log_file=${log_file:-$def_log_file};
cache_old_ip=${cache_old_ip:-$def_cache_old_ip};

#------------------------------------------------------------------

UDD_PATH=`which updatedd`
CURL_PATH=`which curl`
MAIL_PATH=`which mail`

if [ ! ${MAIL_PATH} ] || [ ! -f ${MAIL_PATH} ]; then
	send_mail=0;
fi


touch ${log_file}
touch ${cache_old_ip}

# Actual IP address
ip_act="`dig +short myip.opendns.com @resolver1.opendns.com`"

# Cached IP address
ip_old=`cat ${cache_old_ip}`

# Dynamic DNS IP address
#ip_host="`dig +short ${dhost} @resolver1.opendns.com`"
ip_host="`dig +short ${dhost} @ns101.ovh.net`"

if [ -z "${ip_old}" ]
then
	ip_old="No cached IP"
fi

need_upd=0

# Update if
# ip_act != ip_old
#        OR
# ip_act != ip_host

if [ "${ip_act}" != "${ip_old}" ] || [ "${ip_act}" != "${ip_host}" ]; then
	need_upd=1
fi

if [ "${debug}" = "1" ]
then
	echo "---------------------------------------------------------"
	echo "Username         : ${username}"
	echo "Password         : ${password}"
	echo "Dynamic host     : ${dhost}"

	if [ "${updatedd}" = "1" ]; then
		echo "Update method    : UpdateDD"
		echo "Provider         : "${provider}
	else
		echo "Update method    : Curl"
		echo "URL              : "${curl_url}
	fi

	echo "Send notify email: ${send_mail}                         (1=yes 0=no)"
	echo "Log change ip    : ${log_change}                         (1=yes 0=no)"
	echo "Log no change ip : ${log_no_change}                         (1=yes 0=no)"
	echo "Log path         : ${log_file}"
	echo "Cache ip path    : ${cache_old_ip}"

	echo "---------------------------------------------------------"
	echo "IP actual address: ${ip_act}"
	echo "IP last address  : ${ip_old}"
	echo "IP Dynamic host  : ${ip_host}"

	echo "---------------------------------------------------------"
	echo "Need update?     : ${need_upd}                         (1=yes 0=no)"

	if [ "${ip_act}" != "${ip_old}" ]; then
		echo "Cached IP (${ip_old}) and New IP (${ip_act}) are different"
	fi

	if [ "${ip_act}" != "${ip_host}" ]; then
		echo "Dynamic host (${ip_host}) and New IP (${ip_act}) are different"
	fi
fi

if [ "${need_upd}" = "1" ]; then 
	message="${dhost}: `date`: IP has changed. (Cache: ${ip_old}, Host:${ip_host},  New: ${ip_act})"

	if [ "${send_mail}" = 1 ]; then
		echo ${message} | ${MAIL_PATH} -s "${mail_subject}" ${mail_notify}
	fi

	if [ "${log_change}" = "1" ]; then
		echo "${message}" >> ${log_file}

		if [ "${updatedd}" = "1" ]; then
			${UDD_PATH} ${provider} -- --ipv4 ${ip_act} ${username}:${password} ${dhost} >> ${log_file}
		else
			${CURL_PATH} -s --user "${username}:${password}" "${curl_url}" -o ${log_file}_tmp
			cat ${log_file}_tmp
			echo " "
			cat ${log_file}_tmp >> ${log_file}
			rm -rf ${log_file}_tmp
		fi
	else
		echo "${message}"

		if [ "${updatedd}" = "1" ]; then
			${UDD_PATH} ${provider} -- --ipv4 ${ip_act} ${username}:${password} ${dhost}
		else
			${CURL_PATH} -s --user "${username}:${password}" "${curl_url}"
		fi
	fi
	echo  ${ip_act} > ${cache_old_ip}
else
	message="${dhost}: `date`: No IP change was found"

	if [ "${log_no_change}" = "1" ]; then
		echo "${message}" >> ${log_file}
	fi

	if [ "${debug}" = "1" ]; then
		echo "${message}"
	fi
fi
