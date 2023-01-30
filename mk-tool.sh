#!/usr/bin/env bash

# This script uses latest STABLE as it's default
# Set USE_LATEST=0 to use LATEST STABLE
# Set USE_LATEST=1 to use LATEST VERSION AVAILABLE
USE_LATEST=0
DATE_STAMP=`date +%Y%m%d-%H%M-%S`
MACHINE_NAME="minikube"
MACHINE_STORAGE_PATH="$HOME/.minikube"
TMPPATH="/tmp"
WORKPATH="${TMPPATH}/${MACHINE_NAME}-${DATE_STAMP}"
WORKFILE="${MACHINE_NAME}-${DATE_STAMP}.tgz"
VM_DRIVER="--driver=kvm"
#VM_NET="--apiserver-ips=10.10.10.78"

###
# Container configuration
###
MK_DISKSIZE="16G"
MK_RAM="4096"

command -v minikube >/dev/null 2>&1 || { echo >&2 "I require minikube but it's not installed.  Aborting."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "I require docker but it's not installed.  Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }

###
# Functions
###

get_latest_release() {
	curl --silent "https://api.github.com/repos/kubernetes/kubernetes/releases/latest" | jq -r .tag_name
}

get_latest_stable() {
	minikube config defaults kubernetes-version | head -n1 | cut -d ' ' -f2
}

check_systemd() {
	if [[ $(ps --no-headers -o comm 1) == "systemd" ]]; then
		printf "Detected systemd...\n"
		USE_SYSTEMD="--extra-config=kubelet.cgroup-driver=systemd"
	fi 
}

cleanmk_warn(){
	TIMETOWIPE=5
	printf "╒═══════════════════════════════════════════════════════════════════════════════╕\n"
	printf "│ WARNING!  This script will PERMANENTLY WIPE your minikube machine and cache!! │\n"
	printf "│ Container configuration:  ${MK_DISKSIZE} ${MK_RAM}MB                          │\n"
	while [ ${TIMETOWIPE} -gt -1 ]; do
	TIMETOWIPE_PAD=$(printf "%02d" ${TIMETOWIPE})
	echo -ne ""╘═[$TIMETOWIPE_PAD]══════════════════════════════════════════════════════════════════════════╛"\033[0K\r"
	[ ${TIMETOWIPE} -eq 0 ] && printf "\n"
	sleep 1
	: $((TIMETOWIPE--))
	done
}

check_env() {
        [ -z ${DOCKER_HOST} ] && KUBE_ENV="LOCAL" || KUBE_ENV="MINIKUBE"
}


_error(){
	printf "An error occured.\n"
	exit 250
}

kubever_warn(){
	if [ ${USE_LATEST} -eq 0 ]; then 
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

destroy_virtualbox(){
	printf "╒═════════════════════════════════════════════════════════════════╕\n"
        printf "│ NOTICE!  You have just deleted your VirtualBox configuration    │\n"
        printf "╘═════════════════════════════════════════════════════════════════╛\n"
	rm -rfv ~/.config/VirtualBox
}

version(){
	printf "Minikube-Tool\n"
	printf "Version 0.2\n"
	printf "https://github.com/smashkode/minikube-tool\n"
}

install_ver(){
	[ ${USE_LATEST} -eq 0 ] && KUBE_VERSION=${STABLE_KUBERNETES} || KUBE_VERSION=${DEFAULT_KUBERNETES}
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
	if [ $USE_LATEST == "1" ]; then
		KUBE_VERSION=`get_latest_release kubernetes/kubernetes`
	else
		KUBE_VERSION=`get_latest_stable`
	fi
	check_systemd
	[[ -f ${MACHINE_STORAGE_PATH}/mkt.run ]] && $(${MACHINE_STORAGE_PATH}/mkt.run) || minikube start --kubernetes-version ${KUBE_VERSION} ${VM_NET} ${USE_SYSTEMD} ${VM_DRIVER} --insecure-registry=localhost:5000 --disk-size ${MK_DISKSIZE} --cpus 2 --memory ${MK_RAM}
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
					echo "-d, --default-kube		Use the minikube default kubernetes version"
					echo "-e, --run				Destroy, reinstall, and start minikube"
					echo "-n, --no-wipe			Start minikube without wiping minikube"
					echo "-V, --virtualbox			Destroy VirtualBox configuration"
					echo "-v, --version			Show version"
					exit 0
					;;

			-d|--default-kube)
					USE_LATEST=1
					kubever_warn
					shift
					;;

			-n|--no-wipe)
					NO_WIPE=1
					shift
					;;

			-v|--version)
					version
					RAN=1
					;;

			-e|--run)
					install_ver
					run_program
					cleanup
					RAN=1
					shift
					;;
			-V|--virtualbox)
					destroy_virtualbox
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
