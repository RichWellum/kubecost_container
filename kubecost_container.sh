#!/bin/bash
#
# Code to provide kubecost and kubecost plugin
#

function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

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
            echo -en "${green}${on_success}${nc}"
        else
            echo -en "${red}${on_fail}${nc}"
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

function install_kubecost() {
    # Install kubecost krew plugin
    os=$(uname | tr '[:upper:]' '[:lower:]') && \
    arch=$(uname -m | tr '[:upper:]' '[:lower:]' | sed -e s/x86_64/amd64/) && \
    curl -s -L https://github.com/kubecost/kubectl-cost/releases/latest/download/kubectl-cost-$os-$arch.tar.gz | tar xz -C /tmp && \
    chmod +x /tmp/kubectl-cost && \
    mv /tmp/kubectl-cost /usr/local/bin/kubectl-cost
}

function enable_kubecost() {
    # Enable kubecost on the target cluster
    KUBECOST=$(kubectl get namespaces | grep kubecost)
    if [ -z "$KUBECOST" ]; then
        start_spinner 'Starting kubecost....'
        kubectl create namespace kubecost &>/dev/null
        helm repo add kubecost https://kubecost.github.io/cost-analyzer/ &>/dev/null
        helm install kubecost kubecost/cost-analyzer --namespace kubecost --set kubecostToken="cmljaHdlbGx1bUBnbWFpbC5jb20=xm343yadf98" &>/dev/null
        sleep 3
        POD=$(kubectl get pods --all-namespaces | grep kubecost-cost-analyzer | awk '{print $2}')
        while [ $(kubectl get pod $POD -n kubecost | grep 3/3 | wc -l | xargs) != "1" ]; do
            sleep 5
            echo "Waiting for kubecost-cost-analyzer to be ready."
        done
        sleep 30 # Seems to take a while when first starting
        stop_spinner $?
    fi
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
    echo -e "Projected monthly rate for each deployment in Viya4 duration the last 5 days" >>/home/kubecost_container.kubecost
    echo -e "----------------------------------------------------------------------------\n" >>/home/kubecost_container.kubecost
    kubectl cost deployment \
        --window 5d \
        --show-all-resources \
        >>/home/kubecost_container.kubecost
    echo >>/home/kubecost_container.kubecost

    cat /home/kubecost_container.kubecost
}
export -f get_kubecost_data

install_kubecost
enable_kubecost

echo "Try running 'get_kubecost_data'..."
echo
echo "Run 'kubectl cost -h' - for more options"

source ~/.bashrc
bash