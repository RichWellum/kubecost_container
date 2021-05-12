#!/bin/bash
#
# Code to provide kubecost and kubecost plugin
#

export on_success="DONE"
export on_fail="FAIL"
export white="\e[1;37m"
export GREEN="\e[1;32m"
export RED="\e[1;31m"
export CYAN='\033[0;36m'
export NC="\e[0m"

export PATH="${PATH}:${HOME}/.krew/bin"

function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    case $1 in
    start)
        # calculate the column where spinner and status msg will be displayed
        let column=$(tput cols)-${#2}-8
        # display message and position the cursor in $column column
        echo -en ${CYAN}${2}
        echo -en ${NC}
        printf "%${column}s"

        # start spinner
        i=1
        sp='\|/-'
        delay=${SPINNER_DELAY:-0.15}

        while :; do
            printf "\b${sp:i++%${#sp}:1}"
            sleep $delay
        done
        ;;
    stop)
        if [[ -z ${3} ]]; then
            echo "spinner is not running.."
            exit 1
        fi

        kill $3 >/dev/null 2>&1

        # inform the user uppon success or failure
        echo -en "\b["
        if [[ $2 -eq 0 ]]; then
            echo -en "${GREEN}${on_success}${nc}"
        else
            echo -en "${RED}${on_fail}${nc}"
        fi
        echo -e "]"
        ;;
    *)
        echo "invalid argument, try {start/stop}"
        exit 1
        ;;
    esac
}

function start_spinner() {
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
    # use sleep to give spinner time to fork and run
    # because cp fails instantly
    sleep 1
    echo
}

function stop_spinner() {
    # $1 : command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

function enable_kubecost_check() {
    # Enable kubecost on the target cluster
    KUBECOST=$(kubectl get namespaces | grep kubecost)
    if [ -z "$KUBECOST" ]; then
        echo -en ${RED}
        echo "Kubecost not running on this cluster, do you wish to install?"
        select yn in "Yes" "No"; do
            case $yn in
            Yes)
                enable_kubecost
                return
                ;;
            No) exit ;;
            esac
        done
        echo -en ${NC}
    fi
}

function enable_kubecost() {
    # Enable kubecost on the target cluster
    start_spinner 'Starting kubecost....'
    kubectl create namespace kubecost &>/dev/null
    helm repo add kubecost https://kubecost.github.io/cost-analyzer/ &>/dev/null
    helm install kubecost kubecost/cost-analyzer --namespace kubecost --set kubecostToken="cmljaHdlbGx1bUBnbWFpbC5jb20=xm343yadf98" &>/dev/null
    sleep 3
    POD=$(kubectl get pods --all-namespaces | grep kubecost-cost-analyzer | awk '{print $2}')
    while [ $(kubectl get pod $POD -n kubecost | grep 3/3 | wc -l | xargs) != "1" ]; do
        sleep 15
        echo -en ${RED}
        echo "Waiting for kubecost-cost-analyzer to be ready."
        echo -en ${NC}
    done
    stop_spinner $?
    echo -en ${GREEN}
    echo "Kubecost enabled. Use: 'helm uninstall kubecost -n kubecost' to uninstall."
    echo -en ${NC}
}

function get_projected_1m_namespace() {
    # Projected monthly costs per namespace
    echo -e "Projected monthly costs per Namespace" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost namespace \
        --show-all-resources --window month >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_actual_1m_namespace_historical() {
    # Actual costs per namespace duration the last 1 month
    echo -e "Actual monthly costs per Namespace" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost namespace \
        --historical \
        --window month \
        --show-all-resources >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_projected_1m_deployment() {
    # Projected monthly rate for each deployment in duration the last 1 month
    echo -e "Projected monthly costs per Deployment" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost deployment \
        --window month \
        --show-all-resources \
        >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_actual_1m_pod() {
    # Actual monthly rate for each pod in duration the last 1 month
    echo -e "Actual monthly costs per Pod" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost pod \
        --window month \
        --historical \
        --show-cpu \
        --show-memory \
        >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function menu() {
    HEIGHT=15
    WIDTH=80
    CHOICE_HEIGHT=7
    BACKTITLE="For Kubecost UI run: 'kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090'. Then navigate to: 'http://127.0.0.1:9090'"
    TITLE="Kubecost Information"
    MENU="Choose one of the following options:"

    while true; do
        OPTIONS=(
            1 "Projected monthly costs per Namespace"
            2 "Actual monthly costs per Namespace"
            3 "Projected monthly costs per Deployment"
            4 "Actual monthly costs per Pod"
            5 "All of the above"
            6 "Break into bash and run your own 'kubectl cost' commands"
            7 "Exit out of container")

        CHOICE=$(dialog --clear \
            --backtitle "$BACKTITLE" \
            --title "$TITLE" \
            --menu "$MENU" \
            $HEIGHT $WIDTH $CHOICE_HEIGHT \
            "${OPTIONS[@]}" \
            2>&1 >/dev/tty)

        clear
        case $CHOICE in
        1)
            echo "You chose: Projected monthly costs per namespace"
            get_projected_1m_namespace
            ;;
        2)
            echo "You chose: Actual monthly costs per namespace"
            get_actual_1m_namespace_historical
            ;;
        3)
            echo "You chose: Projected monthly costs per deployment"
            get_projected_1m_deployment
            ;;
        4)
            echo "You chose: Actual monthly costs per pod"
            get_actual_1m_pod
            ;;
        5)
            echo "You chose: All of the above"
            get_projected_1m_namespace; get_actual_1m_namespace_historical; get_actual_1m_namespace_historical; get_actual_1m_pod
            ;;
        6)
            echo "You chose: Break into bash and run your own commands"
            echo -en ${GREEN}
            kubectl cost -h
            echo
            echo -en ${NC}
            source ~/.bashrc
            bash
            ;;
        7)
            exit 1
            ;;
        esac
    done
}
export -f menu

# Test code for GCP issues
# kubectl version --v=10

enable_kubecost_check
menu
