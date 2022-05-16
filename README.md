# viya_utils

A Docker container that provides some useful tools to the SAS Viya user such as
cost and pause/unpause operations. It uses the kubectl-cost krew plugin, and
presents a simple menu with some kubecost options. But also allows the user the
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
az login
sudo docker run -it --rm -v ~/.kube/:/root/.kube rwellum/viya_utils:latest
```

## Launch and run on GKE

```bash
gcloud auth application-default login
docker run -it --rm -v ~/.kube/:/root/.kube -v ~/.config/gcloud:/root/.config/gcloud rwellum/viya_utils:latest
```

## Launch and run on AWS

TBD

## For the package maintainer

```bash
sudo bash -c "docker system prune -f \
    && docker rmi --force rwellum/viya_utils:latest \
    && docker build -t rwellum/viya_utils:latest . --no-cache && \
    docker push rwellum/viya_utils:latest"
```

## End user to get the latest package

Warning removes everything...

```bash
sudo docker system prune -a
```

## To manually remove kubecost

```bash
helm uninstall kubecost -n kubecost
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
