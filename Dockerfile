FROM ubuntu:latest

# Verbosity levels (false, v, vv)
ENV VERBOSE "false"

ENV TERM xterm-256color

ADD viya_utils.sh /app/
RUN chmod +x /app/viya_utils.sh
ADD node_utils_daemonset.yaml /app/

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    boxes \
    less \
    bc \
    dialog \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl; chmod +x ./kubectl; mv ./kubectl /usr/local/bin/kubectl

# Installing Krew and kubecost krew plugin
RUN KREW_VER="$(uname | tr '[:upper:]' '[:lower:]')_amd64" \
    && curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew{-$KREW_VER.tar.gz,.yaml}" \
    && tar zxvf krew-$KREW_VER.tar.gz \
    && KREW=./krew-$KREW_VER \
    && "$KREW" install --manifest=krew.yaml --archive=krew-$KREW_VER.tar.gz \
    && "$KREW" install cost \
    && "$KREW" install node-shell \
    && "$KREW" update

# Install helm
RUN curl -fsSLk -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh

# Prettify the prompt
RUN echo 'export PS1="[\u@viya_utils] \W # "' >> ~/.bashrc

# Run kubecost, set up some utility functions
CMD /app/viya_utils.sh "${VERBOSE}"