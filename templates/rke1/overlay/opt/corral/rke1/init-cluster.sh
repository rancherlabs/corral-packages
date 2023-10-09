#!/bin/bash

KUBERNETES_VERSION=${CORRAL_kubernetes_version}
CNI=${CORRAL_cni}

# install the latest version of RKE cli
curl -0Ls https://github.com/rancher/rke/releases/latest/download/rke_linux-amd64 >rke
chmod +x rke

# install the latest version of yq (below written in v4.35.2)
curl -0Ls https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 >yq
chmod +x yq

# set paths
poolJSON="$(pwd)/node-pools.json"
clusterYAML="$(pwd)/cluster.yml"

#node pool names
bastion="bastion"
server="server"
agent="agent"

#create file from the node pools json output
echo $CORRAL_corral_node_pools >>$poolJSON

#generate yaml from the node pools json
echo "$(./yq -oy '.' $poolJSON)" >>$clusterYAML

function main() {
    #instantiate node pool arrays
    readarray bastionArray < <(./yq -o=j -I=0 ".$bastion[]" $clusterYAML)
    readarray serverArray < <(./yq -o=j -I=0 ".$server[]" $clusterYAML)
    readarray agentArray < <(./yq -o=j -I=0 ".$agent[]" $clusterYAML)

    #map node pool arrays
    map $bastion "${bastionArray[@]}"
    map $server "${serverArray[@]}"
    map $agent "${agentArray[@]}"

    # merge pools into nodes parent and remove standalone pool parents
    ./yq -i ".nodes = .$bastion *+ .$server *+ .$agent | del(.$bastion) | del(.$server) | del(.$agent)" $clusterYAML

    #add kubernetes version
    value=$KUBERNETES_VERSION ./yq -i ".kubernetes_version = strenv(value)" $clusterYAML

    #add cni
    value=$CNI ./yq -i ".network.plugin = strenv(value)" $clusterYAML

    echo -e "Latest version of cluster yaml: \n$(cat $clusterYAML)"

    #rke up to create the cluster
    ./rke up --config $clusterYAML

    #set kubeconfig
    echo "corral_set kubeconfig=$(cat ./kube_config_cluster.yml | base64 -w 0)"
}

function map() {
    local poolKey="$1"
    shift 1

    local poolArray=("$@")

    serverRole="[etcd, controlplane, worker]"
    agentRole=[worker]

    echo "Pool Key: $poolKey, Node Count: ${#poolArray[@]}"

    if [[ ${#poolArray} == 0 ]]; then
        echo "Pool: [$poolKey] is empty"
        return
    fi

    for i in "${!poolArray[@]}"; do
        # make sure new updates doesn't affect address and internal address keys
        field=".$poolKey.[$i].address" value=$(./yq ".$poolKey.[$i].address" $clusterYAML) ./yq -i "eval(strenv(field)) |= env(value)" $clusterYAML
        field=".$poolKey.[$i].internal_address" value=$(./yq ".$poolKey.[$i].internal_address" $clusterYAML) ./yq -i 'eval(strenv(field)) |= env(value)' $clusterYAML
        field=".$poolKey.[$i].internal_address" value="$(./yq ".$poolKey.[$i].internal_address" $clusterYAML)" ./yq -i "eval(strenv(field)) |= env(value)" $clusterYAML

        # update ssh user output as user for configuration
        field=".$poolKey.[$i].user" value=$(./yq ".$poolKey.[$i].ssh_user" $clusterYAML) ./yq -i 'eval(strenv(field)) |= env(value)' $clusterYAML

        # remove unnecessary fields
        ./yq -i "del(.$poolKey.[$i].name)" $clusterYAML
        ./yq -i "del(.$poolKey.[$i].bastion_address)" $clusterYAML
        ./yq -i "del(.$poolKey.[$i].ssh_user)" $clusterYAML

        if [ "$poolKey" = "$bastion" ] || [ "$poolKey" = "$server" ]; then
            field=".$poolKey.[$i].role" value=$serverRole ./yq -i 'eval(strenv(field)) |= env(value)' $clusterYAML
        elif [ "$poolKey" = "$agent" ]; then
            field=".$poolKey.[$i].role" value=$agentRole ./yq -i 'eval(strenv(field)) |= env(value)' $clusterYAML
        fi

    done

    return
}

main
