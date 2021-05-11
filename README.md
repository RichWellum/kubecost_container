# kubecost_container

A Docker container that provides the kubectl-cost krew plugin, and presents a
simple menu with some kubecost options. But also allows the user the
environment in the container to execute their own kubectl-cost commands.

:bangbang: | Warning: This will deploy kubecost on your cluster if it is not already running.
:---: | :---

:bangbang: |Do: 'helm uninstall kubecost -n kubecost' to clean up
:---: | :---

## All credit to the amazing Kubecost tool and kubectl-cost krew plugin

Please see much more here: <https://www.kubecost.com/> and here
<https://github.com/kubecost/kubectl-cost>

## User Driven Menu

![Alt text](./menu.png?raw=true "Menu")

## Launch and run on Azure

```bash
docker run -it --rm -v ~/.kube/:/root/.kube rwellum/kubecost_container:latest
```

## Launch and run on GKE

```bash
gcloud auth application-default login
docker run -it --rm -v ~/.kube/:/root/.kube -v ~/.config/gcloud:/root/.config/gcloud rwellum/kubecost_container:latest
```

## For the package maintainer

```bash
sudo docker system prune -f
sudo docker rmi --force rwellum/kubecost_container:latest
sudo docker build -t rwellum/kubecost_container:latest . --no-cache
sudo docker push rwellum/kubecost_container:latest
```
