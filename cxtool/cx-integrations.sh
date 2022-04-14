#!/bin/bash

generate=false
deploy=false
namespace=default
endpoint=api.eu2.coralogix.com
appdynamic=true
subdynamic=true
dashboard=false
platform=k8s

function main {

  function send_to_dst {
    if [ "$destination" == "s3" ]; then
      if [ -z "$bucket" ]; then echo "bucket name is empty!"; exit 1; fi
      aws s3 mv ./output/$integration-manifests.yaml s3://$bucket/$integration-manifests.yaml 2>&1
      if [ $? -ne 0 ]; then 
        exit 1
      fi
    
    elif [ "$destination" == "github" ]; then
      if [ -z "$gitusername" ]; then echo "git username is empty!"; exit 1; fi
      if [ -z "$gitrepo" ]; then echo "git repo is empty!"; exit 1; fi
      git clone git@github.com:$gitusername/$gitrepo.git 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
      git add ./output/$integration-manifests.yaml
      git commit -m "Adding fluent-bit-http kubernetes manifests"
      git push 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
      rm -rf ./output

    elif [ "$destination" == "local" ]; then
      if [ -z "$path" ]; then
        echo "local path is empty! exiting..."
        exit 1
      fi
      touch $path 2>&1
      if [ $? -ne 0 ]; then 
        exit 1
      else
        mv ./output/$integration-manifests.yaml $path 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
        rm -rf ./output
      fi
    fi
  }

  function validateDynamic () {
    if [ "$integration" = "fluent-bit-http" ] || [ "$integration" = "fluent-bit-coralogix" ]; then
      if [[ $1 != kubernetes.* ]]; then
        echo "$1 is not valid, must start with kubernetes.*, exiting..."
        exit 1
      else
        return 0
      fi
    elif [ "$integration" = "fluentd-http" ] || [ "$integration" = "fluentd-coralogix" ]; then 
      if [[ $1 == kubernetes.* ]]; then
        echo "$1 is not valid, cannot include kubernetes in the beginning, exiting..."
        exit 1
      fi
    fi
  }
  
#################################################################################################################################################
  function generate {
    if [ -z "$integration" ]; then
      echo "Integration name was no specified! exiting... "
      exit 1
    fi

    if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluent-bit-coralogix" ] && [ "$integration" != "fluentd-http" ] && [ "$integration" != "fluentd-coralogix" ]; then 
    echo "Integration name is not valid"; exit 1; fi

    if [[ ! -d "./output" ]]; then 
      mkdir ./output
    fi

    # Generating templates for fluentbit
    if [[ "$integration" = "fluent-bit-http" ]] || [[ "$integration" = "fluent-bit-coralogix" ]]; then
      if [ $platform == "k8s" ]; then
        if [ -z "$appname" ]; then 
          appname=kubernetes.namespace_name
        fi
        if [ -z "$subsystem" ]; then 
          subsystem=kubernetes.container_name
        fi
        if [ $appdynamic == "true" ]; then 
          validateDynamic ${appname}
          if [ $subdynamic == "true" ]; then
              validateDynamic ${subsystem}
              helm template $integration coralogix-charts-virtual/$integration \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" > ./output/$integration-manifests.yaml 2>&1
              if [ $? -ne 0 ]; then exit 1; fi
          else
              helm template $integration coralogix-charts-virtual/$integration -f ./override-$integration-subsystem.yaml \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" > ./output/$integration-manifests.yaml 2>&1
              if [ $? -ne 0 ]; then exit 1; fi
          fi
        elif [ $subdynamic == "true" ]; then
          helm template $integration coralogix-charts-virtual/$integration -f ./override-$integration-appname.yaml \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}" > ./output/$integration-manifests.yaml 2>&1
          if [ $? -ne 0 ]; then exit 1; fi
        else
          helm template $integration coralogix-charts-virtual/$integration \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}" > ./output/$integration-manifests.yaml 2>&1
          if [ $? -ne 0 ]; then exit 1; fi
        fi
      fi
    fi

    # Generating templates for fluentd-http
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "k8s" ]; then
        if [ -z "$appname" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ]; then 
          subsystem=container_name
        fi
        validateDynamic ${appname}
        validateDynamic ${subsystem}
        helm template $integration coralogix-charts-virtual/$integration \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=${endpoint}" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[7].value=kubelet.service" \
          --set "fluentd.env[8].name=K8S_NODE_NAME" --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./output/$integration-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
      fi
    fi
    
    # Generating templates for fluentd-coralogix
    if [ "$integration" = "fluentd-coralogix" ]; then
      if [ $platform == "k8s" ]; then
        if [ -z "$appname" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ]; then 
          subsystem=container_name
        fi
        validateDynamic ${appname}
        validateDynamic ${subsystem}
        helm template $integration coralogix-charts-virtual/$integration \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=${endpoint}" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=MAX_LOG_BUFFER_SIZE" --set "fluentd.env[7].value=12582912" \
          --set "fluentd.env[8].name=K8S_NODE_NAME"  --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./output/$integration-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then exit 1; fi      
      fi
    fi

    if [[ ! -z "$destination" ]]; then
      send_to_dst $destination
    else
      echo "The generated manifests now exist under './output' directory in the current path"
    fi
    
  } 

#################################################################################################################################################
  function deploy {

    if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluent-bit-coralogix" ] && [ "$integration" != "fluentd-http" ] && [ "$integration" != "fluentd-coralogix" ]; then 
    echo "Integration chart name is not valid"; exit ; fi

    if [ -z "$cluster" ]; then
      echo "Cluster arg is empty! exiting... "
      exit 1
    fi

    kubectl config use-context $cluster 2>&1
    if [ $? -ne 0 ]; then exit 1; fi

    if [ -z "$privatekey" ]; then
      echo "Private Key is empty! exiting..."
      exit 1
    fi

    # Creating the integrations secret if it doesn't exist
    `kubectl get secret integrations-privatekey -n $namespace -oyaml >> ./check-secret.yaml 2>&1`
    if [ `cat ./check-secret.yaml | grep -i 'not found' | wc -l` = 1 ]; then 
      echo "integrations-privatekey secret doesnt exist, creating secret..."
      if [ `cat ./check-secret.yaml | grep -i 'namespace' | wc -l` = 1 ]; then
        echo "Creating secret 'integrations-privatekey' in namespace $namespace..."
        kubectl create namespace $namespace
        kubectl create secret generic integrations-privatekey -n $namespace --from-literal=PRIVATE_KEY=$privatekey
      else
        kubectl create secret generic integrations-privatekey -n $namespace --from-literal=PRIVATE_KEY=$privatekey
      fi
    fi 
    rm -f ./check-secret.yaml

    # Deploying Fluent-Bit
    if [[ "$integration" = "fluent-bit-http" ]] || [[ "$integration" = "fluent-bit-coralogix" ]]; then
      if [ $platform == "k8s" ]; then
        if [ -z "$appname" ]; then 
          appname=kubernetes.namespace_name
        fi
        if [ -z "$subsystem" ]; then 
          subsystem=kubernetes.container_name
        fi
        if [ $appdynamic == "true" ]; then 
          validateDynamic ${appname}
          if [ $subdynamic == "true" ]; then
              validateDynamic ${subsystem}
              helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" 2>&1
              if [ $? -ne 0 ]; then exit 1; fi      
          else
              helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace -f ./override-$integration-subsystem.yaml \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" 2>&1
              if [ $? -ne 0 ]; then exit 1; fi
          fi
        elif [ $subdynamic == "true" ]; then
          helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace -f ./override-$integration-appname.yaml \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}" 2>&1
          if [ $? -ne 0 ]; then exit 1; fi
        else
          helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}"  2>&1
          if [ $? -ne 0 ]; then exit 1; fi
        fi
      fi
    fi 

    # Deploying Fluentd-http
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "k8s" ]; then
        if [ -z "$appname" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ]; then 
          subsystem=container_name
        fi
        validateDynamic ${appname}
        validateDynamic ${subsystem}
        helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=${endpoint}" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[7].value=kubelet.service" \
          --set "fluentd.env[8].name=K8S_NODE_NAME" --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./output/$integration-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
      fi
    fi
    
    # Deploying Fluentd-coralogix
    if [ "$integration" = "fluentd-coralogix" ]; then
      if [ $platform == "k8s" ]; then
        if [ -z "$appname" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ]; then 
          subsystem=container_name
        fi
        validateDynamic ${appname}
        validateDynamic ${subsystem}
        helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=${endpoint}" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=MAX_LOG_BUFFER_SIZE" --set "fluentd.env[7].value=12582912" \
          --set "fluentd.env[8].name=K8S_NODE_NAME"  --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./output/$integration-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
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
        echo "Usage:" 
        echo "  cx-integrations [Command] [Flags] integration"
        echo ""
        echo "Available integrations:"
        echo "  fluentd-http, fluent-bit-http, fluentd-coralogix, fluent-bit-coralogix"
        echo ""
        echo "Commands:"
        echo "  generate              Generating manifests for the desired integration and sending it to the desired destination."
        echo "  deploy                Deploying desired integration in the specified platform."           
        echo ""  
        echo "Common Flags:"
        echo "  privatekey            Mandatory, the 'send-your-logs' key"
        echo "  endpoint|-e           Optional, Coralogix default endpoint is 'api.eu2.coralogix.com'."
        echo "  appname               Optional, default is kubernetes namespace name."
        echo "  subsystem             Optional, default is kubernetes container name."
        echo "  appdynamic            Default is true, if changing the appname to static, this flag is mandatory and must be set to false."
        echo "  subdynamic            Default is true, if changing the subsystem to static, this flag is mandatory and must be set to false."
        echo "  platform              The platform to generate/deploy for, k8s or terraform. Optional, default platform is k8s"
        echo ""
        echo "Deploy Flags:"
        echo "  cluster               Mandatory, the name of the kubernetes cluster to deploy in." 
        echo "  dashboard             Whether to import the integration dashboard to the hosted Grafana. Optional, default is false"
        echo "  namespace|-n          Optional, default namespace is 'default"
        echo ""
        echo "Generate Flags:"
        echo "  destination|-d        Mandatory, the destination of the integration manifests - GitHub/S3/local."
        echo "  path                  Mandatory when using the 'local' destination"
        echo "  bucket                Mandatory when using the 's3' destination"
        echo "  gitusername           Mandatory when using the 'github' destination"
        echo "  gitrepo               Mandatory when using the 'github' destination"
        echo ""
        echo "Examples:"
        echo "  cx-integrations generate --appdynamic false --appname Prod --platform k8s --destination s3 --bucket mybucket --fluent-bit-http"
        echo "  cx-integrations deploy --cluster dev --privatekey 1234"

        return 0
        ;;
        *)
        integration="${1}"
        ;;
    esac
    shift

  done

  if [[ "$generate" = true ]] && [[ "$deploy" = false ]]; then 
    generate "$@"; 
  elif [[ "$deploy" = true ]] && [[ "$generate" = false ]]; then
    deploy "$@";
  else
    echo "No command was specified, see 'cx-integrations --help'"
    exit 1
  fi

}

main "$@"
