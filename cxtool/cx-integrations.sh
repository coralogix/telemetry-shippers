#!/bin/bash

generate=false
deploy=false
namespace=default
endpoint=api.eu2.coralogix.com
integration=
appname=kubernetes.namespace_name
subsystem=kubernetes.container_name
bucket=
gitrepo=
gitusername=
cluster=
destination=
appdynamic=true
subdynamic=true
dashboard=false
platform=k8s
privatekey=

function main {

  function send_to_dst {
    if [ "$destination" == "s3" ]; then
      aws s3 cp ./$integration-manifests.yaml $bucket
    elif [ "$destination" == "github" ]; then
      git clone git@github.com:$gitusername/$gitrepo.git
      git add ./$integration-manifests.yaml
      git commit -m "Adding fluent-bit-http kubernetes manifests"
      git push
    elif [ "$destination" == "local" ]; then
      if [ -z "$path" ]; then
        echo "local path is empty! exiting..."
        exit 1
      fi
      touch $path
      cp ./$integration-manifests.yaml $path
    fi
  }
  
#################################################################################################################################################
  function generate {

    if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluent-bit-coralogix" ] && [ "$integration" != "fluentd-http" ] && [ "$integration" != "fluentd-coralogix" ]; then 
    echo "Integration chart name is not valid"; exit ; fi

    # Generating templates for fluentbit
    if [[ "$integration" = "fluent-bit-http" ]] || [[ "$integration" = "fluent-bit-coralogix" ]]; then
      if [ $platform == "k8s" ]; then
        if [ $appdynamic == "true" ]; then
          if [ $subdynamic == "true" ]; then
              echo "both dynamic"
              helm template $integration coralogix-charts-virtual/$integration \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" > ./$integration-manifests.yaml
          else
              echo "subsystem is static"
              helm template $integration coralogix-charts-virtual/$integration -f ./override-$integration-subsystem.yaml \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" > ./$integration-manifests.yaml
          fi
        elif [ $subdynamic == "true" ]; then
          echo "appname is static"
          helm template $integration coralogix-charts-virtual/$integration -f ./override-$integration-appname.yaml \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}" > ./$integration-manifests.yaml
        else
          echo "both static"
          helm template $integration coralogix-charts-virtual/$integration \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}" > ./$integration-manifests.yaml
        fi
      fi
    fi

    # Generating templates for fluentd-http
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "k8s" ]; then
        helm template $integration coralogix-charts-virtual/$integration \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=api.eu2.coralogix.com" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[7].value=kubelet.service" \
          --set "fluentd.env[8].name=K8S_NODE_NAME" --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./$integration-manifests.yaml
      fi
    fi
    
    # Generating templates for fluentd-coralogix
    if [ "$integration" = "fluentd-coralogix" ]; then
      if [ $platform == "k8s" ]; then
        helm template $integration coralogix-charts-virtual/$integration \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=api.eu2.coralogix.com" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=MAX_LOG_BUFFER_SIZE" --set "fluentd.env[7].value=12582912" \
          --set "fluentd.env[8].name=K8S_NODE_NAME"  --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./$integration-manifests.yaml
      fi
    fi

    send_to_dst $destination

  } 

#################################################################################################################################################
  function deploy {

    if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluent-bit-coralogix" ] && [ "$integration" != "fluentd-http" ] && [ "$integration" != "fluentd-coralogix" ]; then 
    echo "Integration chart name is not valid"; exit ; fi

    if [ -z "$cluster" ]; then
      echo "Cluster arg is empty! exiting... "
      exit 1
    fi

    kubectl config use-context $cluster

    if [ -z "$privatekey" ]; then
      echo "Private Key is empty! exiting..."
      exit 1
    fi

    # Creating the integrations secret if not exists
    `kubectl get secret integrations-privatekey -n $namespace -oyaml >> ./check-secret.yaml 2>&1`
    if [ `cat ./check-secret.yaml | grep -i 'not found' | wc -l` = 1 ]; then 
      echo "integrations-privatekey secret doesnt exist, creating secret..."
      if [ `cat ./check-secret.yaml | grep -i 'namespace' | wc -l` = 1 ]; then
        kubectl create namespace $namespace
        kubectl create secret generic integrations-privatekey -n $namespace --from-literal=PRIVATE_KEY=$privatekey
      else
        kubectl create secret generic integrations-privatekey -n $namespace --from-literal=PRIVATE_KEY=$privatekey
      fi
    else
      echo "integrations-privatekey secret already exists"
    fi 
    rm -f ./check-secret.yaml

    # Deploying Fluent-Bit
    if [[ "$integration" = "fluent-bit-http" ]] || [[ "$integration" = "fluent-bit-coralogix" ]]; then
      if [ $platform == "k8s" ]; then
        if [ $appdynamic == "true" ]; then
          if [ $subdynamic == "true" ]; then
              echo "both dynamic"
              helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}"
          else
              echo "subsystem is static"
              helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace -f ./override-$integration-subsystem.yaml \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}"
          fi
        elif [ $subdynamic == "true" ]; then
          echo "appname is static"
          helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace -f ./override-$integration-appname.yaml \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}"
        else
          echo "both static"
          helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}"
        fi
      fi
    fi 

    # Deploying Fluentd-http
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "k8s" ]; then
        helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=api.eu2.coralogix.com" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[7].value=kubelet.service" \
          --set "fluentd.env[8].name=K8S_NODE_NAME" --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./$integration-manifests.yaml
      fi
    fi
    
    # Deploying Fluentd-coralogix
    if [ "$integration" = "fluentd-coralogix" ]; then
      if [ $platform == "k8s" ]; then
        helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=api.eu2.coralogix.com" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=MAX_LOG_BUFFER_SIZE" --set "fluentd.env[7].value=12582912" \
          --set "fluentd.env[8].name=K8S_NODE_NAME"  --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./$integration-manifests.yaml
      fi
    fi
  }

#################################################################################################################################################
  while [ $# -gt 0 ]; do
    case "$1" in
        generate) 
        generate=true
        ;;
        deploy) 
        deploy=true
        ;;
      --namespace|-n)
        if [[ "$1" != *=* ]]; then shift; fi
        namespace="${1#*=}"
        ;;
      --endpoint|-e)
        if [[ "$1" != *=* ]]; then shift; fi
        endpoint="${1#*=}"
        ;;
      --appdynamic)
        if [[ "$1" != *=* ]]; then shift; fi
        appdynamic="${1#*=}"
        ;;
      --subdynamic)
        if [[ "$1" != *=* ]]; then shift; fi
        subdynamic="${1#*=}"
        ;;
      --destination|-d)
        if [[ "$1" != *=* ]]; then shift; fi
        destination="${1#*=}"
        ;;
      --platform)
        if [[ "$1" != *=* ]]; then shift; fi
        platform="${1#*=}"
        ;;
      --gitrepo)
        if [[ "$1" != *=* ]]; then shift; fi
        gitrepo="${1#*=}"
        ;;
      --gitusername)
        if [[ "$1" != *=* ]]; then shift; fi
        gitusername="${1#*=}"
        ;;    
      --bucket)
        if [[ "$1" != *=* ]]; then shift; fi
        bucket="${1#*=}"
        ;;
      --path)
        if [[ "$1" != *=* ]]; then shift; fi
        path="${1#*=}"
        ;;  
      --cluster)
        if [[ "$1" != *=* ]]; then shift; fi
        cluster="${1#*=}"
        ;;
      --dashboard)
        if [[ "$1" != *=* ]]; then shift; fi
        dashboard="${1#*=}"
        ;;        
      --appname)
        if [[ "$1" != *=* ]]; then shift; fi
        appname="${1#*=}"
        ;;
      --subsystem)
        if [[ "$1" != *=* ]]; then shift; fi
        subsystem="${1#*=}"
        ;;
      --privatekey)
        if [[ "$1" != *=* ]]; then shift; fi
        privatekey="${1#*=}"
        ;;
      --help|-h)
        echo "cx-integrations generates integrations manifests and deploys the integrations helm charts"
        echo ""
        echo "Usage: ./cx-integrations.sh [Command] [Flags] ... integration"
        echo ""
        echo "Commands:"
        echo "generate          Generating manifests for the desired integration and sending it to the desired destination."
        echo "deploy            Deploying desired integration helm chart in the specified cluster."           
        echo ""  
        echo "Flags:"
        echo "privatekey        Mandatory, the 'send-your-logs' key"
        echo "endpoint|-e       Optional, Coralogix default endpoint is 'api.eu2.coralogix.com'."
        echo "appname           Optional, default is kubernetes namespace name."
        echo "subsystem         Optional, default is kubernetes container name."
        echo "appdynamic        Default is true, if changing the appname to static, this flag is mandatory and must be set to false."
        echo "subdynamic        Default is true, if changing the subsystem to static, this flag is mandatory and must be set to false."
        echo "platform          The platform to generate/deploy for, k8s or terraform. Optional, default platform is k8s"
        echo ""
        echo "Deploy Flags:"
        echo "cluster           Mandatory, the name of the kubernetes cluster to deploy in." 
        echo "dashboard         Whether to import the integration dashboard to the hosted Grafana. Optional, default is false"
        echo "namespace|-n      Optional, default namespace is 'default"
        echo ""
        echo "Generate Flags:"
        echo "destination|-d    Mandatory, the destination of the integration manifests - GitHub/S3/local."
        echo "path              Mandatory when using the 'local' destination"
        echo "bucket            Mandatory when using the 's3' destination"
        echo "gitusername       Mandatory when using the 'github' destination"
        echo "gitrepo           Mandatory when using the 'github' destination"
        echo ""
        echo "Examples:"
        echo ""
        echo "./cx-integrations.sh generate --appdynamic false --appname Prod --platform k8s --destination s3 --bucket mybucket --fluent-bit-http"
        echo "./cx-integrations.sh deploy --cluster dev-shared.eu-west-1.k8s-rnd.coralogix.net"

        return 0
        ;;
        *)
        integration="${1}"
        ;;
    esac
    shift

  done

  if [[ "$generate" = true ]] && [[ "$deploy" = false ]]; then generate "$@"; fi
  if [[ "$deploy" = true ]] && [[ "$generate" = false ]]; then deploy "$@"; fi
}

main "$@"
