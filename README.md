# kubecost_container

A Docker container to provide a container that is ready to run the kubecost krew
plugin, and presents a simple menu with some kubecost options.

:bangbang: | Warning: This *will* install kubecost into your cluster
:---: | :---

## All credit to the amazing Kubecost tool

Please see much more here: <https://www.kubecost.com/>

## User Driven Menu

![Alt text](./menu.png?raw=true "Menu")

## Launch and run

```bash
docker run -it --rm -v ~/.kube/:/root/.kube rwellum/kubecost_container:latest
```

## For the package maintainer

```bash
sudo docker system prune -f
sudo docker rmi --force rwellum/kubecost_container:latest
sudo docker build -t rwellum/kubecost_container:latest . --no-cache
sudo docker push rwellum/kubecost_container:latest
```
