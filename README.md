# kubecost_container

A Docker container that provides the kubectl-cost krew plugin, and presents a
simple menu with some kubecost options. But also allows the user the
environment in the container to execute their own kubectl-cost commands.

| :bangbang: | Warning: This will deploy kubecost on your cluster if it is not already running. |
| :--------: | :------------------------------------------------------------------------------- |

| :bangbang: | Do: 'helm uninstall kubecost -n kubecost' to clean up |
| :--------: | :---------------------------------------------------- |

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
sudo bash -c "docker system prune -f \
    && docker rmi --force rwellum/kubecost_container:latest \
    && docker build -t rwellum/kubecost_container:latest . --no-cache && \
    docker push rwellum/kubecost_container:latest"
```

## End user to get the latest package

Warning removes everything...

```bash
    sudo docker system prune -a
```

## Todo

- Add pause and unpause

Stop a SAS Viya DeploymentTo stop your SAS Viya deployment, create a new job
that runs immediately from the sas-stop-all CronJob:

```bash
kubectl create job sas-stop-all-`date +%s` --from cronjobs/sas-stop-all -n
name-of-namespace
```

Start a SAS Viya DeploymentTo start your SAS Viya deployment, create a new job that
runs immediately from the sas-start-all CronJob:

```bash
kubectl create job sas-start-all-`date +%s` --from cronjobs/sas-start-all -n name-of-namespace
```
