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

#       Node  Disk  Disk  Mem  Mem  Inst  Linux CPU  Thr  CPU% CR    Stor  Taints
HEADER="%-34s %-10s %-10s %-9s %-9s %-17s %-19s %-5s %-5s %-5s %-11s %-10s %-10s\n"

# Update from image build time
kubectl krew update &>/dev/null

# Remove goland debugs
unset DEBUG

function menu() {
    HEIGHT=20
    WIDTH=70
    CHOICE_HEIGHT=14
    BACKTITLE="For Kubecost UI run: 'kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090'. Then navigate to: 'http://127.0.0.1:9090'"
    TITLE="Utils and Cost Information"
    MENU="Choose one of the following options:"

    while true; do
        OPTIONS=(
            1 "Actual costs per Namespace (this month)"
            2 "Actual costs per Deployment (this month)"
            3 "Actual costs per Pod (this month)"
            4 "Actual costs per Controller (this month)"
            5 "Projected monthly costs per Namespace (7d window)"
            6 "Break into bash and run your own 'kubectl cost' commands"
            7 "Stop/Pause a Viya Instance"
            8 "Start/Unpause a Viya Instance"
            9 "Monitor a Cluster (Ctrl-c to quit)"
            10 "Monitor a Cluster - bad state (Ctrl-c to quit)"
            11 "SAS Viya Breakdown"
            12 "EXIT")

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
            echo "You chose: Actual monthly costs per namespace..."
            get_actual_month_namespace
            ;;
        2)
            echo "You chose: Actual monthly costs per deployment..."
            get_actual_month_deployment
            ;;
        3)
            echo "You chose: Actual monthly costs per pod..."
            get_actual_month_pod
            ;;
        4)
            echo "You chose: Actual monthly costs per controller..."
            get_actual_month_controller
            ;;
        5)
            echo "You chose: Projected monthly costs per namespace..."
            get_projected_month_7d_window_namespace
            ;;
        6)
            echo "You chose: Break into bash and run your own 'kubectl cost' commands..."
            echo -en ${GREEN}
            kubectl cost -h
            echo
            echo -en ${NC}
            source ~/.bashrc
            bash
            ;;
        7)
            echo "You chose: Stop/Pause a Viya Instance..."
            echo -en ${GREEN}
            stop_viya
            echo -en ${NC}
            ;;
        8)
            echo "You chose: Start/Unpause a Viya Instance..."
            echo -en ${GREEN}
            start_viya
            echo -en ${NC}
            ;;
        9)
            echo "You chose: Monitor a Cluster..."
            echo -en ${GREEN}
            monitor_cluster
            echo -en ${NC}
            ;;
        10)
            echo "You chose: Monitor a Cluster - bad state"
            echo -en ${GREEN}
            monitor_cluster_not_running
            echo -en ${NC}
            ;;
        11)
            echo "You chose: SAS Viya Breakdown..."
            echo -en ${GREEN}
            run_node_utils_daemonset
            echo -en ${NC}
            ;;
        12)
            exit 1
            ;;
        esac
    done
}
export -f menu

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

function stop_viya() {
    # Stop a viya
    NS=$(kubectl get namespace --no-headers=true | grep -v 'kube-\|default\|cert\|nfs\|ingress\|kubecost\|monitor\|logging' | awk '{print $1}')
    SELECTION=1

    while read -r line; do
        echo "$SELECTION) $line"
        ((SELECTION++))
    done <<<"$NS"

    ((SELECTION--))

    echo
    printf "Select a Viya Namespace from the above list to stop: "

    read -r opt
    if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
        NAMESPACE=$(sed -n "${opt}p" <<<"$NS")
    fi
    echo
    echo "Stopping Viya Namespace '$NAMESPACE'"
    kubectl create job sas-stop-all-$(date +%s) --from cronjobs/sas-stop-all -n $NAMESPACE &>/dev/null
    monitor_cluster_not_running
}

function start_viya() {
    # Stop a viya
    NS=$(kubectl get namespace --no-headers=true | grep -v 'kube-\|default\|cert\|nfs\|ingress\|kubecost\|monitor\|logging' | awk '{print $1}')
    SELECTION=1

    while read -r line; do
        echo "$SELECTION) $line"
        ((SELECTION++))
    done <<<"$NS"

    ((SELECTION--))

    echo
    printf "Select a Viya Namespace from the above list to start: "

    read -r opt
    if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
        NAMESPACE=$(sed -n "${opt}p" <<<"$NS")
    fi
    echo
    echo "Starting Viya Namespace '$NAMESPACE'"
    kubectl create job sas-start-all-$(date +%s) --from cronjobs/sas-start-all -n $NAMESPACE &>/dev/null
    monitor_cluster_not_running
}

function monitor_cluster() {
    # Light weight look at cluster status
    watch -d kubectl get po -A
}

function monitor_cluster_not_running() {
    # Light weight look at cluster status not running
    watch -d 'kubectl get pods --all-namespaces --sort-by=.spec.nodeName | grep -Ev "(Running|Completed)"'
}

function select_context() {
    # Select a context
    # Save current context
    PREV_CX=$(kubectl config current-context)
    echo "Current CX is: $PREV_CX"
    echo

    # Pick context to run Astrolabe on
    ENTITIES=$(kubectl config get-contexts --no-headers=false -o name)
    SELECTION=1

    while read -r line; do
        echo "$SELECTION) $line"
        ((SELECTION++))
    done <<<"$ENTITIES"

    ((SELECTION--))

    echo
    printf "Select a Context from the above list (enter for $PREV_CX): "

    read -r opt
    if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
        CONTEXTS=$(sed -n "${opt}p" <<<"$ENTITIES")
    fi
    kubectl config use-context $CONTEXTS &>/dev/null
    export CURR_CX=$(kubectl config current-context)
    echo -en ${NC}
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
    echo "Waiting for kubecost to be ready..."
    kubectl wait --for=condition=Ready pod/$POD -n kubecost
    stop_spinner $?
    echo -en ${GREEN}
    echo "Kubecost enabled. Use: 'helm uninstall kubecost -n kubecost' to uninstall."
    echo -en ${NC}
}

function get_actual_month_namespace() {
    # Actual costs per namespace duration the last 1 month
    echo -e "Actual monthly costs per Namespace" | boxes -d stone >/home/viya_utils.kubecost

    kubectl cost namespace \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/viya_utils.kubecost

    echo >>/home/viya_utils.kubecost
    echo -en ${GREEN}
    less /home/viya_utils.kubecost
    echo -en ${NC}
}

function get_actual_month_deployment() {
    # Actual monthly rate for each deployment in duration the last 1 month
    echo -e "Actual monthly costs per Deployment" | boxes -d stone >/home/viya_utils.kubecost

    kubectl cost deployment \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/viya_utils.kubecost

    echo >>/home/viya_utils.kubecost
    echo -en ${GREEN}
    less /home/viya_utils.kubecost
    echo -en ${NC}
}

function get_actual_month_pod() {
    # Actual monthly rate for each pod in duration the last 1 month
    echo -e "Actual monthly costs per Pod" | boxes -d stone >/home/viya_utils.kubecost

    kubectl cost pod \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/viya_utils.kubecost

    echo >>/home/viya_utils.kubecost
    echo -en ${GREEN}
    less /home/viya_utils.kubecost
    echo -en ${NC}
}

function get_projected_month_7d_window_namespace() {
    # Projected monthly costs per namespace using last 7d window
    echo -e "Projected monthly costs per Namespace" | boxes -d stone >/home/viya_utils.kubecost

    kubectl cost namespace \
        --show-all-resources \
        --window 7d \
        >>/home/viya_utils.kubecost

    echo >>/home/viya_utils.kubecost
    echo -en ${GREEN}
    less /home/viya_utils.kubecost
    echo -en ${NC}
}

function get_actual_month_controller() {
    # Actual monthly rate for each controller in duration the last 1 month
    echo -e "Actual monthly costs per Controller" | boxes -d stone >/home/viya_utils.kubecost

    kubectl cost controller \
        --historical \
        --window month \
        --show-all-resources \
        >>/home/viya_utils.kubecost

    echo >>/home/viya_utils.kubecost
    echo -en ${GREEN}
    less /home/viya_utils.kubecost
    echo -en ${NC}
}

#
# Daemonset functions
#
function display_daemonset() {
    return
    echo
    echo -en ${GREEN}
    kubectl get pods -n astrolabe | grep disk-checker
    echo -en ${NC}
    echo
}

function wait_for_daemonset() {
    retries=10
    sleep 1
    desired=$(kubectl get daemonset -n astrolabe -l=app='disk-checker' | grep -v NAME | awk '{print $2}')
    while [[ $retries -ge 0 ]]; do
        ready=$(kubectl get daemonset -n astrolabe -l=app='disk-checker' | grep -v NAME | awk '{print $4}')
        display_daemonset
        if ((ready == desired)); then
            echo -e "${CYAN}Desired ($desired) pods == Ready ($ready) pods....${NC}"
            break
        fi
        ((retries--))
        sleep 5
    done
}

function wait_for_daemonset_to_die() {
    sleep 3
    PODS=$(kubectl get pods -n astrolabe &>/dev/null | grep disk-ckecker | wc -l)
    while [[ $PODS -ne 0 ]]; do
        sleep 3
        PODS=$(kubectl get pods -n astrolabe | grep disk-ckecker | wc -l | sed 's/^[[:space:]]*//g') &>/dev/null
    done
}

function BytesToHuman() {
    # https://unix.stackexchange.com/questions/44040/a-standard-tool-to-convert-a-byte-count-into-human-kib-mib-etc-like-du-ls1/259254#259254

    read StdIn

    b=${StdIn:-0}
    d=''
    s=0
    S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

function get_cni() {
    # Todo - works for Azure only
    system_node=$(kubectl get node | grep "\-cas\-" | awk 'NR==1 {print $1}' | xargs)
    CNI_NAM=$(kubectl node-shell $system_node -- sh -c 'cat /etc/cni/net.d/10-*.conflist | grep name')
    CNI_VER=$(kubectl node-shell $system_node -- sh -c 'cat /etc/cni/net.d/10-*.conflist | grep cniV')
    export CNI_NAM=$(echo $CNI_NAM | awk 'NR==2 {print $1}' | sed 's/,//g' | xargs | sed 's/name://g')
    export CNI_VER=$(echo $CNI_VER | awk 'NR==2 {print $1}' | sed 's/,//g' | xargs | sed 's/cniVersion://g')
    if [[ -z $CNI_NAM ]]; then
        CNI_NAM="false"
        CNI_VER="0"
    fi
}

# Per Cluster totals
function total_up_data() {
    DISK_SIZE=0
    DISK_USED=0
    MEM_SIZE=0
    MEM_USED=0
    while IFS="" read -r line || [ -n "$line" ]; do
        NEW_DISK_SIZE=$(echo $line | awk '{print $2}' | numfmt --from=iec)
        DISK_SIZE=$((DISK_SIZE + NEW_DISK_SIZE))

        NEW_DISK_USED=$(echo $line | awk '{print $3}' | sed 's/([^)]*)//g' | numfmt --from=iec)
        DISK_USED=$((DISK_USED + NEW_DISK_USED))

        NEW_MEM_SIZE=$(echo $line | awk '{print $4}' | numfmt --from=iec)
        MEM_SIZE=$((MEM_SIZE + NEW_MEM_SIZE))

        NEW_MEM_USED=$(echo $line | awk '{print $5}' | sed 's/([^)]*)//g' | numfmt --from=iec)
        MEM_USED=$((MEM_USED + NEW_MEM_USED))
    done </home/astrolabe.pernode_table

    DISK_SIZE=$(echo ${DISK_SIZE} | numfmt --to=iec --format %f)
    DISK_USED=$(echo ${DISK_USED} | numfmt --to=iec --format %f)
    DISK_SIZE_RAW=$(echo $DISK_SIZE | numfmt --from=iec)
    DISK_USED_RAW=$(echo $DISK_USED | numfmt --from=iec)
    DISK_USED_PERC=$((200 * $DISK_USED_RAW / $DISK_SIZE_RAW % 2 + 100 * $DISK_USED_RAW / $DISK_SIZE_RAW))

    MEM_SIZE=$(echo ${MEM_SIZE} | numfmt --to=iec --format %f)
    MEM_USED=$(echo ${MEM_USED} | numfmt --to=iec --format %f)
    MEM_SIZE_RAW=$(echo $MEM_SIZE | numfmt --from=iec)
    MEM_USED_RAW=$(echo $MEM_USED | numfmt --from=iec)
    MEM_USED_PERC=$((200 * $MEM_USED_RAW / $MEM_SIZE_RAW % 2 + 100 * $MEM_USED_RAW / $MEM_SIZE_RAW))

    echo >>/home/astrolabe.pernode_table_sorted
    printf "$HEADER" "" "---------" "---------" "--------" "--------" >>/home/astrolabe.pernode_table_sorted
    printf "$HEADER" "TOTALS:" "$DISK_SIZE" "$DISK_USED($DISK_USED_PERC%)" "$MEM_SIZE" "$MEM_USED($MEM_USED_PERC%)" >>/home/astrolabe.pernode_table_sorted
    printf "$HEADER" "" "---------" "---------" "--------" "--------" >>/home/astrolabe.pernode_table_sorted
    echo >>/home/astrolabe.pernode_table_sorted
}

function get_node_instances() {
    NODES=$(kubectl get nodes | grep -v NAME | awk '{print $1}')
    for node in "${NODES[@]}"; do
        echo "$node"
    done
}

function get_k8s_vers() {
    export CLIENT=$(kubectl version --short 2>/dev/null | grep 'Client Version' | awk '{print $3}')
    export SERVER=$(kubectl version --short 2>/dev/null | grep 'Server Version' | awk '{print $3}')
}

function get_sas_info() {
    export NAMESPACE=$(kubectl get namespace --no-headers | grep -v 'astrolabe' | grep -v 'cert-' | grep -v 'default' | grep -v 'ingress' | grep -v 'kube-' | grep -v 'nfs-client' | grep -v 'lens-' | grep -v 'kubecost' | awk '{print $1;}')
    if [[ -z $NAMESPACE ]]; then
        NAMESPACE="false"
        return
    fi

    SAS_CADENCE=$(kubectl -n $NAMESPACE get cm -o yaml | grep ' SAS_CADENCE_')

    SAS_CADENCE_DISPLAY_SHORT_NAME=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_DISPLAY_SHORT_NAME' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_DISPLAY_SHORT_NAME=${SAS_CADENCE_DISPLAY_SHORT_NAME//\"/}

    SAS_CADENCE_DISPLAY_VERSION=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_DISPLAY_VERSION' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_DISPLAY_VERSION="${SAS_CADENCE_DISPLAY_VERSION/\//_}"

    SAS_CADENCE_RELEASE=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_RELEASE' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_RELEASE=${SAS_CADENCE_RELEASE//\"/}

    SAS_CADENCE_VERSION=$(echo "$SAS_CADENCE" | grep 'SAS_CADENCE_VERSION' | cut -d ":" -f2 | xargs)
    export SAS_CADENCE_VERSION=${SAS_CADENCE_VERSION//\"/}
}

function run_node_utils_daemonset() {
    start_spinner "Deploying Astrolabe Daemonset on Cluster: '${CURR_CX}'...."
    kubectl create namespace astrolabe &>/dev/null
    kubectl apply -f node_utils_daemonset.yaml #&>/dev/null
    wait_for_daemonset
    stop_spinner $?
    start_spinner "Collecting and processing data from Daemonset pods (this takes some time)...."
    # Send logs to a file for further processing
    kubectl logs -l app=disk-checker -n astrolabe --tail=-1 >>/home/astrolabe.pernode

    # Display in table form like all other commands
    # Kubectl commands can be run from here
    # Node specific must be run from the daemonset
    while IFS="" read -r line || [ -n "$line" ]; do
        if [[ ! -z "$line" ]]; then
            if [[ $line != *"Size"* ]] && [[ $line != *"Used"* ]] && [[ $line != *"CPU"* ]]; then
                # This line of text it is the vm node line, e.g.:
                # aks-system-30686869-vmss000000
                # With the node name, per node kubectl calls can be made
                NODE=$line
                INST=$(kubectl describe node $NODE | grep node.kubernetes.io/instance-type | cut -f2- -d=)
                LINUX=$(kubectl describe node $NODE | grep 'OS Image:' | sed 's/OS Image://g' | sed -e 's/^[ \t]*//')
                LINUX="${LINUX// /_}"
                CONTAINER_RUNTIME=$(kubectl describe node $NODE | grep 'Container Runtime Version:' | cut -f2- -d: | cut -f1 -d":" | xargs)
                STORAGE_TIER=$(kubectl describe node $NODE | grep 'storagetier=' | xargs | cut -f2- -d=)
                TAINTS=$(kubectl describe node $NODE | grep 'Taints:' | xargs | cut -f2- -d:)
                CPU_PER=$(kubectl top nodes --no-headers --use-protocol-buffers | grep $NODE | awk '{print $3}')
                continue
            elif [[ $line == *"Disk_Size"* ]]; then
                DISK_SIZE=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --from=iec --format %f)
                continue
            elif [[ $line == *"Disk_Used"* ]]; then
                DISK_USED=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --from=iec --format %f)
                continue
            elif [[ $line == *"Mem_Size"* ]]; then
                MEM_SIZE=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --format %f)
                continue
            elif [[ $line == *"Mem_Used"* ]]; then
                MEM_USED=$(cut -d "=" -f2 <<<"$line" | numfmt --to=iec --format %f)
                continue
            elif [[ $line == *"CPU_Num"* ]]; then
                CPU_NUM=$(cut -d "=" -f2 <<<"$line")
                continue
            elif [[ $line == *"CPU_Threads"* ]]; then
                CPU_THREADS=$(cut -d "=" -f2 <<<"$line")
                continue
            elif [[ $line == *"CPU_Sockets"* ]]; then
                CPU_SOCKETS=$(cut -d "=" -f2 <<<"$line")
                continue
            fi
        fi

        # Percentage used
        DISK_SIZE_RAW=$(echo $DISK_SIZE | numfmt --from=iec)
        DISK_USED_RAW=$(echo $DISK_USED | numfmt --from=iec)
        DISK_USED_PERC=$((200 * $DISK_USED_RAW / $DISK_SIZE_RAW % 2 + 100 * $DISK_USED_RAW / $DISK_SIZE_RAW))

        MEM_SIZE_RAW=$(echo $MEM_SIZE | numfmt --from=iec)
        MEM_USED_RAW=$(echo $MEM_USED | numfmt --from=iec)
        MEM_USED_PERC=$((200 * $MEM_USED_RAW / $MEM_SIZE_RAW % 2 + 100 * $MEM_USED_RAW / $MEM_SIZE_RAW))

        printf "$HEADER" "$NODE" "$DISK_SIZE" "$DISK_USED($DISK_USED_PERC%)" "$MEM_SIZE" "$MEM_USED($MEM_USED_PERC%)" "$INST" "$LINUX" "$CPU_NUM" "$CPU_THREADS" "$CPU_PER" "$CONTAINER_RUNTIME" "$STORAGE_TIER" "$TAINTS" >>/home/astrolabe.pernode_table
    done </home/astrolabe.pernode

    # Sort the table alphabetically
    sort -t$'\t' -k3 -n /home/astrolabe.pernode_table >/home/astrolabe.pernode_table_sorted
    total_up_data

    # Get K8s version
    get_k8s_vers

    # Get SAS Specific info
    get_sas_info

    # Get CNI info
    # get_cni

    # Add header
    sed -i "1s/^/----                               ---------  ---------  --------  --------  ---------         -----               ----  ----  ----  -------     -------      ------\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/NODE                               DISK_SIZE  DISK_USED  MEM_SIZE  MEM_USED  INST_TYPE         LINUX               CPUS  THRS  CPU%  RUNTIME     STORAGE      TAINTS\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/+----------------------+\n\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/| Per Node information |\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/+----------------------+\n/" /home/astrolabe.pernode_table_sorted
    if [[ $NAMESPACE != "false" ]]; then
        sed -i "1s/^/SAS Viya4 Release:    Cadence: ${SAS_CADENCE_DISPLAY_SHORT_NAME}, Version: ${SAS_CADENCE_VERSION}, Date.Epoch: ${SAS_CADENCE_RELEASE}\n\n/" /home/astrolabe.pernode_table_sorted
        sed -i "1s/^/SAS Viya4 Namespace:  ${NAMESPACE}\n/" /home/astrolabe.pernode_table_sorted
    fi

    # if [[ $CNI_NAM != "false" ]]; then
    #     sed -i "1s/^/Networking:           CNI: ${CNI_NAM}, CNI Version: ${CNI_VER}\n/" /home/astrolabe.pernode_table_sorted
    # fi

    if [[ $NAMESPACE != "false" ]]; then
        sed -i "1s/^/K8s Versions:         Client: ${CLIENT}, Server: ${SERVER}\n/" /home/astrolabe.pernode_table_sorted
    else
        sed -i "1s/^/K8s Versions:         Client: ${CLIENT}, Server: ${SERVER}\n\n/" /home/astrolabe.pernode_table_sorted
    fi
    sed -i "1s/^/Cluster Name:         ${CURR_CX}\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/+------------------------+\n\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/| Deployment information |\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/+------------------------+\n/" /home/astrolabe.pernode_table_sorted
    sed -i "1s/^/----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----ASTROLABE----\n\n/" /home/astrolabe.pernode_table_sorted
    stop_spinner $?

    # Cleanup daemonset
    start_spinner 'Destroying Astrolabe Daemonset....'
    kubectl delete daemonset disk-checker -n astrolabe &>/dev/null
    wait_for_daemonset_to_die
    stop_spinner $?

    sleep 3
    echo -e "${CYAN}Displaying data....${NC}"
    sleep 1
    echo
    echo -en ${GREEN}
    cat /home/astrolabe.pernode_table_sorted | boxes -d columns -p a2v1 > /home/astrolabe.pernode_table_sorted_pretty
    less /home/astrolabe.pernode_table_sorted_pretty
    echo -en ${NC}
}

select_context
enable_kubecost_check
menu
