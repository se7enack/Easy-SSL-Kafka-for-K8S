# kafka


## Automatically Generate Kafka certificates
### Usage:
./auto-generate-certificates.sh
###
Files are generated to the newly created 'output' directory

### Apply the auto-generated secrets yaml to your cluster:
kubectl apply -f output/secrets.yaml

### Create ingress
bash ./ingress-create.sh

### Create Kafka and Zookeeper
kubectl apply -f kafka_and_zookeeper.yaml


