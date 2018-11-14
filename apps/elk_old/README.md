Docker Swarm Monitoring
===

Docker Stack compose file to deploy dynamic logging for Docker Swarm. This stack deploys the following services:

* `Elasticsearch`: Database to store the log data and query for it.
* `Logstash`: Log processor that ingests data from multiple sources and feeds it to Elasticsearch.
* `Logspout`: Logspout is deployed to all hosts to collect the logs from docker daemon and feed it to logstash.
* `Kibana`: Web UI to display Elasticsearch data.

Run Instructions
---
Setup a Volume to store the data
```
docker volume create --driver rexray --opt=size=5 --name esdata

docker stack deploy -c docker-stack.yml elk
```
