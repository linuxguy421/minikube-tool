#!/usr/bin/env bash

# This script uses latest STABLE as it's default
# Set USE_DEFAULT=0 to use LATEST STABLE
# Set USE_DEFAULT=1 to use MINIKUBE DEFAULT
USE_DEFAULT=0
DEFAULT_KUBERNETES="v1.23.5"
STABLE_KUBERNETES="v1.23.5"
DATE_STAMP=`date +%Y%m%d-%H%M-%S`
MACHINE_NAME="minikube"
MACHINE_STORAGE_PATH="$HOME/.minikube"
TMPPATH="/tmp"
WORKPATH="${TMPPATH}/${MACHINE_NAME}-${DATE_STAMP}"
WORKFILE="${MACHINE_NAME}-${DATE_STAMP}.tgz"

###
# Functions
###
cleanmk_warn(){
	TIMETOWIPE=5
	printf "╒═══════════════════════════════════════════════════════════════════════════════╕\n"
	printf "│ WARNING!  This script will PERMANENTLY WIPE your minikube machine and cache!! │\n"
	printf "│           Use --backup to backup your minikube docker machine                 │\n"
	while [ ${TIMETOWIPE} -gt -1 ]; do
	TIMETOWIPE_PAD=$(printf "%02d" ${TIMETOWIPE})
	echo -ne ""╘═[$TIMETOWIPE_PAD]══════════════════════════════════════════════════════════════════════════╛"\033[0K\r"
	[ ${TIMETOWIPE} -eq 0 ] && printf "\n"
	sleep 1
	: $((TIMETOWIPE--))
	done
}

function check_env() {
        [ -z ${DOCKER_HOST} ] && KUBE_ENV="LOCAL" || KUBE_ENV="MINIKUBE"
}


_error(){
	printf "An error occured.\n"
	exit 250
}

kubever_warn(){
	if [ ${USE_DEFAULT} -eq 0 ]; then 
	printf "╒═════════════════════════════════════════════════════════════════╕\n"	
	printf "│ WARNING!  Minikube will use kubernetes ${STABLE_KUBERNETES} which is not the │\n"
	printf "│           default of ${DEFAULT_KUBERNETES}                                    │\n"
	printf "│           Use --default-kube to override this behavior          │\n"	
	printf "╘═════════════════════════════════════════════════════════════════╛\n"
	else
	printf "╒═════════════════════════════════════════════════════════════════╕\n"
	printf "│ NOTICE!   You have selected the default minikube kubernetes     │\n"
	printf "│           ${DEFAULT_KUBERNETES}                                               │\n"
	printf "╘═════════════════════════════════════════════════════════════════╛\n"
fi
}

destroy_network(){
	printf "╒═════════════════════════════════════════════════════════════════╕\n"
        printf "│ NOTICE!  I really hope you know what you've just done!          │\n"
        printf "╘═════════════════════════════════════════════════════════════════╛\n"
	rm -rfv ~/.config/VirtualBox
}

backup_minikube(){
	printf "Preparing to backup ${MACHINE_STORAGE_PATH}...\n"
	[[ ! -d ${MACHINE_STORAGE_PATH}/ ]] && _error || \
	mkdir -p ${WORKPATH}/
	cp -R ${MACHINE_STORAGE_PATH}/ ${WORKPATH}/
	_VMS=$(vboxmanage list vms | grep minikube | cut -d " " -f1)
	_VMS="${_VMS%\"}"; VMS="${_VMS#\"}"
	[[ -z ${VMS} ]] && _error || \
	minikube stop
	vboxmanage export ${VMS} -o ${WORKPATH}/${VMS}.ova
	tar cf - ${WORKPATH} -P | pv -s $(du -sb ${WORKPATH}/ | awk '{print $1}') | gzip > ${WORKFILE}
	rm -rf ${WORKPATH}/
}

restore_minikube(){
	TIMETOWIPE=5
	printf "╒═══════════════════════════════════════════════════════════════════════╕\n"
	printf "│ WARNING!  This option will OVERWRITE your current minikube machine !! │\n"
	while [ ${TIMETOWIPE} -gt -1 ]; do
	TIMETOWIPE_PAD=$(printf "%02d" ${TIMETOWIPE})
	echo -ne ""╘═[$TIMETOWIPE_PAD]══════════════════════════════════════════════════════════════════╛"\033[0K\r"
	[ ${TIMETOWIPE} -eq 0 ] && printf "\n"
	sleep 1
	: $((TIMETOWIPE--))
	done

	#[[ -d ${MACHINE_STORAGE_PATH} ]] && minikube delete ${MACHINE_NAME} 
	rm -rf ${MACHINE_STORAGE_PATH}
	printf "Restoring ${RESTORE_FILE} to ${MACHINE_STORAGE_PATH}/machines/${MACHINE_NAME}\n"
	mkdir -p ${MACHINE_STORAGE_PATH}/machines/${MACHINE_NAME}/
	pv ${RESTORE_FILE} | tar xzf - -C ${HOME} 2>/dev/null
	RESTORED_VERSION=`jq ".KubernetesConfig.KubernetesVersion" ${MACHINE_STORAGE_PATH}/profiles/${MACHINE_NAME}/config.json`
	printf "Setting version to ${RESTORED_VERSION}\n"
	[[ ${RESTORED_VERSION} == "${STABLE_KUBERNETES}" ]] && KUBE_VERSION=${STABLE_KUBERNETES} || KUBE_VERSION=${DEFAULT_KUBERNETES}
	printf "Your minikube installation has been restored from ${RESTORE_FILE} using ${RESTORED_VERSION}.\n"
}

version(){
	printf "Minikube-Tool\n"
	printf "Version 0.1.1\n"
	printf "https://github.com/gergme/minikube-tool\n"
}

install_ver(){
	[ ${USE_DEFAULT} -eq 0 ] && KUBE_VERSION=${STABLE_KUBERNETES} || KUBE_VERSION=${DEFAULT_KUBERNETES}
}

cleanup(){
	rm -rf $TMPPATH/$MACHINE_NAME*
	rm -rf ${MACHINE_STORAGE_PATH}/mkt.run
}

destroy(){
	cleanmk_warn
	minikube delete
	rm -rf ~/.minikube/cache
	rm -rf ${MACHINE_STORAGE_PATH}/mkt.run
}

run_program(){
	tput clear 
	version	
	check_env
	[[ ${NO_WIPE} -ne 1 ]] && destroy || \
	kubever_warn
	#[[ -z ${KUBE_VERSION} ]] && KUBE_VERSION=`jq ".KubernetesConfig.KubernetesVersion" ${MACHINE_STORAGE_PATH/profiles/${MACHINE_NAME}/config.json`
	[[ -f ${MACHINE_STORAGE_PATH}/mkt.run ]] && $(${MACHINE_STORAGE_PATH}/mkt.run) || minikube start --kubernetes-version ${KUBE_VERSION} --insecure-registry=localhost:5000 --disk-size 30g --cpus 2 --memory 4096
	eval $(minikube docker-env)
	docker run -d -p 5000:5000 --restart=always --name registry registry:2
	printf "NOTICE!  Your docker environment is currently set to ${KUBE_ENV}!\n"
	printf "\tUse \"eval \$(minikube docker-env)\" for MINIKUBE\n"
	printf "\tUse \"eval \$(minikube docker-env --unset)\" for LOCAL\n"
	printf "minikube start --kubernetes-version ${KUBE_VERSION} --insecure-registry=localhost:5000" > ${MACHINE_STORAGE_PATH}/mkt.run
	minikube status
}

###
# App
###
while test $# -gt 0; do
		case "$1" in
			-h|--help)
					version
					echo "syntax:  ${0} [-b] [-d] [-n] [-R]"
					echo "options:"
					echo "-h, --help			Its what youre looking at!"
					echo "-b, --backup			Backup the minikube virtual machine"
					echo "-d, --default-kube		Use the minikube default kubernetes version of ${DEFAULT_KUBERNETES}"
					echo "-n, --no-wipe			Start minikube without wiping minikube installation"
					echo "-r, --restore [file]		Restore a minikube virtual machine"
					echo "-R, --run			Run the script"
					echo "-N, --network			Destroy VirtualBox networking"
					echo "-v, --version			Show version"
					exit 0
					;;

			-b|--backup)
					backup_minikube
					RAN=1
					shift
					;;
			-d|--default-kube)
					USE_DEFAULT=1
					kubever_warn
					shift
					;;

			-n|--no-wipe)
					NO_WIPE=1
					shift
					;;

			-r|--restore)
					RESTORE_FILE=${2}
					restore_minikube
					RAN=1
					;;

			-v|--version)
					version
					RAN=1
					;;

			-R|--run)
					install_ver
					run_program
					cleanup
					RAN=1
					shift
					;;
			-N|--network)
					destroy_network
					shift
					exit 0
					;;
			*)
					printf "Unknown option!\n"
					RAN=1
					$0 --help
					exit 0
					;;
		esac
done

###
# Exit
###
[ "${RAN}" == "1" ] && exit 0 || \
printf "Here, I'll help you out...\n"
$0 --help
exit 0
