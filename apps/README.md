Docker Swarm Apps
===

Swarm Visualizer
---

```bash
# Startup the Visualizer Service
docker service create \
  --name=viz \
  --publish=8080:8080/tcp \
  --constraint=node.role==manager \
  --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  dockersamples/visualizer

# Add a LB rule to access the Visualizer (Optional)
./lb.sh <unique> create visualizer 8080:8080
```

Deploy the Hello World Stack
```bash
# Deploy the Private Registry Stack
docker stack deploy --compose-file helloworld/docker-stack.yml helloworld
```


Deploy the Private Registry Stack
```bash
# Deploy the Private Registry Stack
docker stack deploy --compose-file registry/docker-stack.yml registry

# Add a LB rule to access Private Registry WebSite (Optional)
./lb.sh <unique> create visualizer 8081:5001
```



Hello World Test
---

```bash
# Start the Stack
docker stack deploy --compose-file helloworld/docker-stack.yml helloworld

# Remove the Stack
docker stack rm helloworld
```



ELK Deploy
---

Run Private Registry on a localhost Computer (Not Swarm)
```bash
# Docker Compose up the Registry
docker-compose -d -f registry/docker-stack.yml up

#or
docker run -d -p 5000:5000 --name=registry \
  -e REGISTRY_STORAGE=azure \
  -e REGISTRY_STORAGE_AZURE_CONTAINER="registry" \
  -e REGISTRY_STORAGE_AZURE_ACCOUNTNAME="<your_account>" \
  -e REGISTRY_STORAGE_AZURE_ACCOUNTKEY="<your_key>" \
  registry:2

# View Registry on localhost
http://localhost:5001/home
```


Build the Stack on a localhost Computer (Not Swarm)
```bash
REGISTRY=127.0.0.1:5000 TAG=latest
docker-compose -f elk/docker-stack.yml build

for SERVICE in logstash; do
  docker tag elk_$SERVICE $REGISTRY/$SERVICE:$TAG
  docker push $REGISTRY/$SERVICE
done
```

Deploy the Elk Stack
```bash
# Start the Stack
docker stack deploy --compose-file elk/docker-stack.yml elk

# Remove the Stack
docker stack rm elk
```
>Note: Full spin up time for Elk is about 5 minutes dependent upon how many nodes and CPU.
