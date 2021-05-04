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
}

function get_kubecost_data() {
    # kubecost commands and outputs
    #
    # There are several supported subcommands: namespace, deployment, controller,
    # label, and tui, which display cost information aggregated by the name of the
    # subcommand (see Examples). Each subcommand has two primary modes, rate and
    # non-rate. Rate (the default) displays the projected monthly cost based on the
    # activity during the window. Non-rate (--historical) displays the total cost
    # for the duration of the window.

    # Historical=total cost for the duration of the window
    # Non-historical = the projected monthly cost during window

    echo "KubeCost Information" | boxes -d stone >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost

    # Projected monthly costs per namespace
    echo -e "Projected monthly costs per namespace" >>/home/kubecost_container.kubecost
    echo -e "-------------------------------------\n" >>/home/kubecost_container.kubecost

    kubectl cost namespace \
        --show-all-resources >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost

    # Actual costs per namespace duration the last 5 days
    echo -e "Actual costs per namespace duration the last 5 days" >>/home/kubecost_container.kubecost
    echo -e "---------------------------------------------------\n" >>/home/kubecost_container.kubecost
    kubectl cost namespace \
        --historical \
        --window 5d \
        --show-all-resources >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost

    # Projected monthly rate for each deployment in Viya4 duration the last 5 days
    echo -e "Projected monthly rate for each deployment in the last 5 days" >>/home/kubecost_container.kubecost
    echo -e "----------------------------------------------------------------------------\n" >>/home/kubecost_container.kubecost
    kubectl cost deployment \
        --window 5d \
        --show-all-resources \
        >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}
export -f get_kubecost_data

function get_projected_monthly() {
    # Projected monthly costs per namespace
    echo -e "Projected monthly costs per namespace" | boxes -d stone >/home/kubecost_container.kubecost

    kubectl cost namespace \
        --show-all-resources >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_actual_5_days() {
    # Actual costs per namespace duration the last 5 days
    echo -e "Actual costs per namespace duration the last 5 days" | boxes -d stone >/home/kubecost_container.kubecost
    kubectl cost namespace \
        --historical \
        --window 5d \
        --show-all-resources >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function get_projected_5_days() {
    # Projected monthly rate for each deployment in duration the last 5 days
    echo -e "Projected monthly rate for each deployment in the last 5 days" | boxes -d stone >/home/kubecost_container.kubecost
    kubectl cost deployment \
        --window 5d \
        --show-all-resources \
        >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost
    echo -en ${GREEN}
    less /home/kubecost_container.kubecost
    echo -en ${NC}
}

function menu() {
    HEIGHT=15
    WIDTH=80
    CHOICE_HEIGHT=6
    BACKTITLE="Kubecost Container"
    TITLE="Kubecost Information"
    MENU="Choose one of the following options:"

    while true; do
        OPTIONS=(
            1 "Projected monthly costs per namespace"
            2 "Actual costs per namespace duration the last 5 days"
            3 "Projected monthly rate for each deployment in the last 5 days"
            4 "All of the above"
            5 "Break into bash and run your own 'kubectl cost' commands"
            6 "Exit out of container")

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
            get_projected_monthly
            ;;
        2)
            echo "You chose: Actual costs per namespace duration the last 5 days"
            get_actual_5_days
            ;;
        3)
            echo "You chose: Projected monthly rate for each deployment in the last 5 days"
            get_projected_5_days
            ;;
        4)
            echo "You chose: All of the above"
            get_projected_monthly; get_actual_5_days; get_projected_5_days
            ;;
        5)
            echo "You chose: Break into bash and run your own commands"
            echo -en ${GREEN}
            echo "Try running: 'get_kubecost_data'..."
            echo "Run: 'kubectl cost -h' - for more options"
            echo -en ${NC}
            source ~/.bashrc
            bash
            ;;
        6)
            exit 1
            ;;
        esac
    done
}
export -f menu

enable_kubecost_check
menu
