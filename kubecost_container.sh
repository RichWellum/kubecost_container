#!/bin/bash
#
# Code to provide kubecost and kubecost plugin in a nice UI with some cool
# options and the ability to break in and run kubectl krew plugins as needed.
#

export on_success="DONE"
export on_fail="FAIL"
export white="\e[1;37m"
export GREEN="\e[1;32m"
export RED="\e[1;31m"
export CYAN='\033[0;36m'
export NC="\e[0m"

export PATH="${PATH}:${HOME}/.krew/bin"
export DEBUG=false

# Update from image build time
kubectl krew update &>/dev/null

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

function get_actual_month_namespace() {
    # Actual costs per namespace duration the last 1 month
    echo -e "Actual monthly costs per Namespace" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost namespace \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_actual_month_deployment() {
    # Actual monthly rate for each deployment in duration the last 1 month
    echo -e "Actual monthly costs per Deployment" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost deployment \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_actual_month_pod() {
    # Actual monthly rate for each pod in duration the last 1 month
    echo -e "Actual monthly costs per Pod" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost pod \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_projected_month_7d_window_namespace() {
    # Projected monthly costs per namespace using last 7d window
    echo -e "Projected monthly costs per Namespace" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost namespace \
        --show-all-resources \
        --window 7d \
        >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_actual_month_controller() {
    # Actual monthly rate for each controller in duration the last 1 month
    echo -e "Actual monthly costs per Controller" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost controller \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/kubecost_container.kubecost

    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function menu() {
    HEIGHT=15
    WIDTH=65
    CHOICE_HEIGHT=8
    BACKTITLE="For Kubecost UI run: 'kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090'. Then navigate to: 'http://127.0.0.1:9090'"
    TITLE="Kubecost Information"
    MENU="Choose one of the following options:"

    while true; do
        OPTIONS=(
            1 "Actual monthly costs per Namespace"
            2 "Actual monthly costs per Deployment"
            3 "Actual monthly costs per Pod"
            4 "Actual monthly costs per Controller"
            5 "Projected monthly costs per Namespace"
            6 "All of the above"
            7 "Break into bash and run your own 'kubectl cost' commands"
            8 "Exit out of container")

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
            echo "You chose: Actual monthly costs per namespace"
            get_actual_month_namespace
            ;;
        2)
            echo "You chose: Actual monthly costs per deployment"
            get_actual_month_deployment
            ;;
        3)
            echo "You chose: Actual monthly costs per pod"
            get_actual_month_pod
            ;;
        4)
            echo "You chose: Actual monthly costs per controller"
            get_actual_month_controller
            ;;
        5)
            echo "You chose: Projected monthly costs per namespace"
            get_projected_month_7d_window_namespace
            ;;
        6)
            echo "You chose: All of the above"
            get_actual_month_namespace
            get_actual_month_deployment
            get_actual_month_pod
            get_actual_month_controller
            get_projected_month_7d_window_namespace
            ;;
        7)
            echo "You chose: Break into bash and run your own commands"
            echo -en ${GREEN}
            kubectl cost -h
            echo
            echo -en ${NC}
            source ~/.bashrc
            bash
            ;;
        8)
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
