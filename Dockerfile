FROM ubuntu:latest

# Verbosity levels (false, v, vv)
ENV VERBOSE "false"

ENV TERM xterm-256color

# Debugging true or false
ENV DEBUG "false"

ADD kubecost_container.sh /app/
RUN chmod +x /app/kubecost_container.sh

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    less \
    ca-certificates \
    boxes \
    dialog \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl; chmod +x ./kubectl; mv ./kubectl /usr/local/bin/kubectl

# Installing Krew and kubecost krew plugin
RUN curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.{tar.gz,yaml}" && \
    tar zxvf krew.tar.gz && \
    KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" && \
    "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz && \
    "$KREW" install cost && \
    "$KREW" update

# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh

# Prettify the prompt
RUN echo 'export PS1="[\u@docker_kubecost] \W # "' >> ~/.bashrc

# Run kubecost, set up some utility functions
CMD /app/kubecost_container.sh "${@}"