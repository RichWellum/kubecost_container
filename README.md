# kubecost_container

A Docker container to provide a container that is ready to run kubecost krew
plugin.

Warning this **will** install kubecost into your cluster - it is not localized
to the docker container.

## Launch and run

```bash
docker run -it --rm -v ~/.kube/:/root/.kube rwellum/kubecost_container:latest
```

## Once in the container try

```bash
get_kubecost_data
```

## For the package maintainer

```bash
sudo docker system prune -f
sudo docker rmi --force rwellum/kubecost_container:latest
sudo docker build -t rwellum/kubecost_container:latest . --no-cache
sudo docker push rwellum/kubecost_container:latest
````
