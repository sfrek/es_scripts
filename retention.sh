#!/bin/bash

source snapshots.conf

TODAY=$(date +%s)
YESTERDAY=$(( TODAY - 86400 ))
TODAY_SUFIX=$(date --date="@${TODAY}" +%Y.%m.%d)
YESTERDAY_SUFIX=$(date --date="@${YESTERDAY}" +%Y.%m.%d)
declare -A INDICES
declare -A RETENTION
INDICES=(["packlinkpro_api"]=1
["packlinkpro_billing"]=7
["packlinkpro_carrier"]=7
["packlinkpro_carrierintegration"]=7
["packlinkpro_carrierintegrationbartolini"]=7
["packlinkpro_carrierpriceengine"]=1
["packlinkpro_client"]=1
["packlinkpro_cub"]=1
["packlinkpro_ecommerceintegrations"]=7
["packlinkpro_kokudo"]=7
["packlinkpro_locations"]=1
["packlinkpro_notification"]=1
["packlinkpro_packoffice"]=1
["packlinkpro_pricecalculator"]=7
["packlinkpro_purchase"]=7
["packlinkpro_reports"]=1
["packlinkpro_shipments"]=7
["packlinkpro_shipmentsautocomplete"]=1
["packlinkpro_trackingupdates"]=1)

RETENTION=(["packlinkpro_api"]=7
["packlinkpro_billing"]=28
["packlinkpro_carrier"]=28
["packlinkpro_carrierintegration"]=28
["packlinkpro_carrierintegrationbartolini"]=28
["packlinkpro_carrierpriceengine"]=7
["packlinkpro_client"]=7
["packlinkpro_cub"]=7
["packlinkpro_ecommerceintegrations"]=74
["packlinkpro_kokudo"]=74
["packlinkpro_locations"]=7
["packlinkpro_notification"]=7
["packlinkpro_packoffice"]=7
["packlinkpro_pricecalculator"]=74
["packlinkpro_purchase"]=74
["packlinkpro_reports"]=7
["packlinkpro_shipments"]=74
["packlinkpro_shipmentsautocomplete"]=7
["packlinkpro_trackingupdates"]=7)
# Seconds per day 60 * 60 * 24
STEP=86400

# __main__
[[ $# < 1 ]] && echo "missing arguments..." && exit 1

ACTION=${1}

case ${ACTION} in
	create)
		for INDEX in ${!INDICES[@]}
		do
			[ ! -d ${INDEX} ] && mkdir ${INDEX}
			# STEPS: How long each microservice gonna be in production, in days		
			STEPS=${INDICES["${INDEX}"]}
			# FROM: From date in life
			FROM=$(( TODAY - $(( ${STEPS} * ${STEP} )) ))
			# REMOVE_FROM: From this to after dates we have to remove
			REMOVE_FROM=$(( FROM - STEP ))
			
			echo -en "\e[01;34m${INDEX}-${TODAY_SUFIX}\e[01;37m [ \e[01;32m"
			curl -s -o /dev/null -w %{http_code} http://${HOST}:9200/${INDEX}-${TODAY_SUFIX}
			echo -e "\e[01;37m ]\e[00m ${STEPS} days ago in life"

			echo -e "\e[01;35m+++++++++++++++++++++++ IN LIFE +++++++++++++++++++"
			for INDEX_DATE in $(seq ${FROM} ${STEP} ${YESTERDAY})
			do
				THE_INDEX=${INDEX}-$(date --date="@${INDEX_DATE}" +%Y.%m.%d) 

				echo -en "\t\e[01;35m${THE_INDEX}\t[ \e[01;37m"
				curl -s -o /dev/null -w %{http_code} http://${HOST}:9200/${THE_INDEX}
				echo -e "\e[01;35m ]\e[00m"
			done


			echo -e "\e[01;36m+++++++++ INDEX TO GO OUT FROM LIFE  ++++++++++++++++"
			declare -a INDICES_LIST
			for INDEX_DATE in $(seq ${REMOVE_FROM} -${STEP} ${EDGE_DATE})
			do
				THE_INDEX=${INDEX}-$(date --date="@${INDEX_DATE}" +%Y.%m.%d) 
				HTTP_CODE=$(curl -s -o /dev/null -w %{http_code} http://${HOST}:9200/${THE_INDEX})

				echo -en "\t\e[01;36m${THE_INDEX}\t[ "
				[[ ${HTTP_CODE} != 200 ]] && echo -e "\e[01;31m${HTTP_CODE}\e[01;36m ]\e[00m" && break
				echo -e "\e[01;32m${HTTP_CODE}\e[01;36m ]\e[00m"

				INDICES_LIST+="${THE_INDEX} "
				touch ${INDEX}/${THE_INDEX}
			done
			# CREATE SNAPSHOT
			./snapshots.sh create ${INDEX}_$(date +%Y%m%d) ${INDICES_LIST[@]}
			# DELETE INDICES
			./indices.sh close ${INDICES_LIST[@]}
			./indices.sh delete ${INDICES_LIST[@]}
			INDICES_LIST=''
		done
		echo -e "\e[00m"
		;;
	restore)
		for INDEX in ${!INDICES[@]}
		do
			[ ! -d ${INDEX} ] && mkdir ${INDEX}
			# STEPS: How long each microservice gonna be in production, in days		
			REMOVE_STEPS=${INDICES["${INDEX}"]}
			RESTORE_STEPS=${RETENTION["${INDEX}"]}
			# FROM: From date in retention life
			RESTORE_FROM=$(( TODAY - $(( ${REMOVE_STEPS} * ${STEP} )) ))
			RESTORE_TO=$(( RESTORE_FROM - $(( ${RESTORE_STEPS} * ${STEP} )) - STEP ))
			RESTORE_FROM_SUFIX=$(date --date="@${RESTORE_FROM}" +%Y.%m.%d)

			echo -en "\e[01;34m${INDEX}-${TODAY_SUFIX}\e[01;37m [ \e[01;32m"
			curl -s -o /dev/null -w %{http_code} http://${HOST}:9200/${INDEX}-${TODAY_SUFIX}
			echo -e "\e[01;37m ]\e[00m ${REMOVE_STEPS} days ago in life"

			echo -en "\e[01;34m${INDEX}-${RESTORE_FROM_SUFIX}\e[01;37m [ \e[01;32m"
			curl -s -o /dev/null -w %{http_code} http://${HOST}:9200/${INDEX}-${TODAY_SUFIX}
			echo -e "\e[01;37m ]\e[00m ${RESTORE_STEPS} days ago in retention life"

			echo -e "\e[01;35m+++++++++++++++++++++++ IN LIFE +++++++++++++++++++"
			for INDEX_DATE in $(seq ${RESTORE_FROM} -${STEP} ${RESTORE_TO})
			do
				THE_INDEX=${INDEX}-$(date --date="@${INDEX_DATE}" +%Y.%m.%d) 

				echo -en "\t\e[01;35m${THE_INDEX}\t[ \e[01;37m"
				curl -s -o /dev/null -w %{http_code} http://${HOST}:9200/${THE_INDEX}
				echo -e "\e[01;35m ]\e[00m"
			done


			# echo -e "\e[01;36m+++++++++ INDEX TO GO OUT FROM LIFE  ++++++++++++++++"
			# declare -a INDICES_LIST
			# for INDEX_DATE in $(seq ${REMOVE_FROM} -${STEP} ${EDGE_DATE})
			# do
			# 	THE_INDEX=${INDEX}-$(date --date="@${INDEX_DATE}" +%Y.%m.%d) 
			# 	HTTP_CODE=$(curl -s -o /dev/null -w %{http_code} http://${HOST}:9200/${THE_INDEX})

			# 	echo -en "\t\e[01;36m${THE_INDEX}\t[ "
			# 	[[ ${HTTP_CODE} != 200 ]] && echo -e "\e[01;31m${HTTP_CODE}\e[01;36m ]\e[00m" && break
			# 	echo -e "\e[01;32m${HTTP_CODE}\e[01;36m ]\e[00m"

			# 	INDICES_LIST+="${THE_INDEX} "
			# 	touch ${INDEX}/${THE_INDEX}
			# done
			# INDICES_LIST=''
		done
		echo -e "\e[00m"
		;;
	*)
		echo "wrong arguments ..."
		;;
esac
