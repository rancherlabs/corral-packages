#!/bin/bash

export node_to_delete=$(kubectl get nodes --sort-by=".metadata.creationTimestamp" -o name | tail -n 1)
export node_address=$(kubectl get $node_to_delete -o custom-columns=:.status.addresses[1].address --no-headers)

kubectl delete $node_to_delete
