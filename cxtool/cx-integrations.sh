#!/bin/bash

generate=false
deploy=false
namespace=default
endpoint=api.eu2.coralogix.com
appdynamic=true
subdynamic=true
platform=kubernetes
outputdir=output
destination=local

function main {

  function upload {
    if [ "$destination" == "s3" ]; then
      if [ -z "$bucket" ]; then echo "bucket name is empty!"; exit 1; fi
      if [ -z "$bucketpath" ]; then 
        aws s3 mv ./$outputdir/$integration-manifests.yaml s3://$bucket/$integration-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then 
          exit 1
        fi
      else
        aws s3 mv ./$outputdir/$integration-manifests.yaml s3://$bucket/$bucketpath/$integration-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then 
          exit 1
        fi      fi
    
    elif [ "$destination" == "github" ]; then
      if [ -z "$giturl" ]; then echo "git url is empty!"; exit 1; fi
      git clone $giturl 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
      git add ./$outputdir/$integration-manifests.yaml
      git commit -m "Adding fluent-bit-http kubernetes manifests"
      git push 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
      rm -rf ./$outputdir

    elif [ "$destination" == "local" ]; then
      if [ ! -z "$path" ]; then
        mv ./$outputdir/$integration-manifests.yaml $path 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
        rm -rf ./$outputdir
      else
        echo "The generated manifests now exist under './$outputdir' directory in the current path"
      fi
    fi
  }

  function validateDynamic () {
    if [ $1 == "true" ]; then #dynamic
      if [ "$integration" = "fluent-bit-http" ]; then
        if [[ $2 != kubernetes.* ]]; then
          echo "$2 is not valid, must start with kubernetes.*, exiting..."
          exit 1
        else
          return 0
        fi
      elif [ "$integration" = "fluentd-http" ]; then 
        if [[ $2 == kubernetes.* ]]; then
          echo "$2 is not valid, cannot include kubernetes in the beginning, exiting..."
          exit 1
        fi
      fi
    else #static
      if [ "$integration" = "fluent-bit-http" ]; then
        if [ -z "$2" ]; then echo "when appdynamic/subdynamic is false - the value must be specified [appname/subsystem]"; exit 1; fi
        if [[ $2 == kubernetes.* ]]; then
          echo "$2 is not valid, cannot start with kubernetes.*, exiting..."
          exit 1
        else
          return 0
        fi
      elif [ "$integration" = "fluentd-http" ]; then 
        echo "fluentd-http supports only dynamic appname and subname, exiting..."
        exit 1
      fi
    fi
  }

  function check_secret_exists {
    # Creating the integrations secret if it doesn't exist
    kubectl get namespace $namespace 2>&1 > /dev/null
    if [ $? -ne 0 ]; then kubectl create namespace $namespace; fi
    kubectl get secret integrations-privatekey -n $namespace -oyaml 2>&1 > /dev/null
    if [ $? -ne 0 ]; then 
      echo "Creating secret 'integrations-privatekey' in namespace $namespace..." 
      kubectl create secret generic integrations-privatekey -n $namespace --from-literal=PRIVATE_KEY=$privatekey 2>&1
      if [ $? -ne 0 ]; then 
        exit 1;
      else
        return 0;
      fi 
    fi
  }

  function helmInstalled { 
    which helm 2>&1 > /dev/null
    if [ $? -ne 0 ]; then
      echo "helm is not installed, do you want to install it now ? y/n" 
      read ans
      if [ $ans == 'n' ]; then
        exit 1;
      else
        echo "installing helm..." 
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
        chmod 700 get_helm.sh 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
        ./get_helm.sh 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
        rm -f ./get_helm.sh
      fi
    fi
  }
  
#################################################################################################################################################
  function generate {

    if [ -z "$integration" ]; then
      echo "Integration name was no specified! exiting... "
      exit 1
    fi
  
    if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluentd-http" ]; then 
    echo "Integration name is not valid"; exit 1; fi

    if [[ ! -d "./$outputdir" ]]; then 
      mkdir ./$outputdir
    fi

    # Generating templates for fluentbit
    if [ "$integration" = "fluent-bit-http" ] ; then
      if [ "$platform" = "kubernetes" ]; then
        helmInstalled 
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=kubernetes.namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=kubernetes.container_name
        fi
        validateDynamic ${appdynamic} ${appname}
        validateDynamic ${subdynamic} ${subsystem}
        if [ $appdynamic == "true" ]; then 
          if [ $subdynamic == "true" ]; then
              helm template $integration coralogix-charts-virtual/$integration \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" > ./$outputdir/$integration-manifests.yaml 2>&1
              if [ $? -ne 0 ]; then exit 1; fi
          else
              helm template $integration coralogix-charts-virtual/$integration -f ./override-$integration-subsystem.yaml \
                --set "fluent-bit.app_name=${appname}" \
                --set "fluent-bit.sub_system=${subsystem}" \
                --set "fluent-bit.endpoint=${endpoint}" > ./$outputdir/$integration-manifests.yaml 2>&1
              if [ $? -ne 0 ]; then exit 1; fi
          fi
        elif [ $subdynamic == "true" ]; then
          helm template $integration coralogix-charts-virtual/$integration -f ./override-$integration-appname.yaml \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}" > ./$outputdir/$integration-manifests.yaml 2>&1
          if [ $? -ne 0 ]; then exit 1; fi
        else #both static
          helm template $integration coralogix-charts-virtual/$integration \
            --set "fluent-bit.app_name=${appname}" \
            --set "fluent-bit.sub_system=${subsystem}" \
            --set "fluent-bit.endpoint=${endpoint}" > ./$outputdir/$integration-manifests.yaml 2>&1
          if [ $? -ne 0 ]; then exit 1; fi
        fi
      else
        exit 1
      fi
    fi

    # Generating templates for fluentd-http
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "kubernetes" ]; then
        helmInstalled 
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=container_name
        fi
        validateDynamic ${appdynamic} ${appname}
        validateDynamic ${subdynamic} ${subsystem}
        # Fluentd doesnt support 'envwithtpl' like Fluentbit, meaning it doesn't template the configuration,
        # so the overrides must be set like the following, and include all of the environment variables, even if they are similar to the defaults : 
        helm template $integration coralogix-charts-virtual/$integration \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=${endpoint}" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[7].value=kubelet.service" \
          --set "fluentd.env[8].name=K8S_NODE_NAME" --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" > ./$outputdir/$integration-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
      fi
    fi
  
    upload $destination
    
  } 

#################################################################################################################################################
  function deploy {

    if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluentd-http" ]; then 
    echo "Integration chart name is not valid"; exit ; fi

    if [[ ! -z "$cluster" ]]; then
      kubectl config use-context $cluster 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
    fi

    if [ -z "$privatekey" ]; then
      echo "Private Key is empty! exiting..."
      exit 1
    fi

    helmInstalled
    check_secret_exists

    # Deploying Fluent-Bit
    if [ "$integration" = "fluent-bit-http" ]; then
      if [ $platform == "kubernetes" ]; then
        helmInstalled 
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=kubernetes.namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=kubernetes.container_name
        fi
        validateDynamic ${appdynamic} ${appname}
        validateDynamic ${subdynamic} ${subsystem}
        if [ $appdynamic == "true" ]; then 
          if [ $subdynamic == "true" ]; then
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
    # Fluentd doesnt support 'envwithtpl' like Fluentbit, meaning it doesn't template the configuration,
    # so the overrides must be set like the following, and include all of the environment variables, even if they are similar to the defaults :
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "kubernetes" ]; then
        helmInstalled 
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=container_name
        fi
        validateDynamic ${appdynamic} ${appname}
        validateDynamic ${subdynamic} ${subsystem}
        helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
          --set "fluentd.env[0].name=APP_NAME" --set "fluentd.env[0].value=${appname}" \
          --set "fluentd.env[1].name=SUB_SYSTEM" --set "fluentd.env[1].value=${subsystem}" \
          --set "fluentd.env[2].name=APP_NAME_SYSTEMD" --set "fluentd.env[2].value=systemd" \
          --set "fluentd.env[3].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[3].value=kubelet.service" \
          --set "fluentd.env[4].name=ENDPOINT" --set "fluentd.env[4].value=${endpoint}" \
          --set "fluentd.env[5].name=FLUENTD_CONF" --set "fluentd.env[5].value=../../etc/fluent/fluent.conf" \
          --set "fluentd.env[6].name=LOG_LEVEL" --set "fluentd.env[6].value=error" \
          --set "fluentd.env[7].name=SUB_SYSTEM_SYSTEMD" --set "fluentd.env[7].value=kubelet.service" \
          --set "fluentd.env[8].name=K8S_NODE_NAME" --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
      fi
    fi   
  }

#################################################################################################################################################
  function apply { 

    if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluentd-http" ]; then 
    echo "Integration chart name is not valid"; exit ; fi

    if [[ ! -z "$cluster" ]]; then
      kubectl config use-context $cluster 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
    fi

    generate "$@";
    echo "Applying manifests..."
    
    if [ -z "$privatekey" ]; then
      echo "Private Key is empty! exiting..."
      exit 1
    fi

    check_secret_exists

    kubectl apply -f ./$outputdir/$integration-manifests.yaml -n $namespace
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
        apply) 
        apply=true
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
      --giturl)
        if [[ "$1" != *=* ]]; then shift; fi
        giturl="${1#*=}"
        ;;
      --bucket)
        if [[ "$1" != *=* ]]; then shift; fi
        bucket="${1#*=}"
        ;;
      --bucketpath)
        if [[ "$1" != *=* ]]; then shift; fi
        bucketpath="${1#*=}"
        ;;
      --path)
        if [[ "$1" != *=* ]]; then shift; fi
        path="${1#*=}"
        ;;  
      --cluster)
        if [[ "$1" != *=* ]]; then shift; fi
        cluster="${1#*=}"
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
        echo "  fluentd-http, fluent-bit-http"
        echo ""
        echo "Commands:"
        echo "  generate                Generating manifests for the desired integration and sending it to the desired destination."
        echo "  deploy                  Deploying desired integration with Helm."
        echo "  apply                   Deploying desired integration to Kubernetes without Helm."           
        echo ""  
        echo "Common Flags:"
        echo "  --endpoint|-e           Optional, Coralogix default endpoint is 'api.eu2.coralogix.com'."
        echo "  --appname               Optional, default is kubernetes namespace name."
        echo "  --subsystem             Optional, default is kubernetes container name."
        echo "  --appdynamic            Default is true, if changing the appname to static, this flag is mandatory and must be set to false."
        echo "  --subdynamic            Default is true, if changing the subsystem to static, this flag is mandatory and must be set to false."
        echo "  --platform              The platform to generate/deploy for, currently the available platform is kubernetes"
        echo ""
        echo "Deploy Flags:"
        echo "  --privatekey            Mandatory, the 'send-your-logs' key"
        echo "  --cluster               Optional, the name of the kubernetes cluster to deploy in. Default is the current context" 
        echo "  --namespace|-n          Optional, default namespace is 'default"
        echo ""
        echo "Apply Flags:"
        echo "  --privatekey            Mandatory, the 'send-your-logs' key"
        echo "  --cluster               Optional, the name of the kubernetes cluster to deploy in. Default is the current context" 
        echo "  --namespace|-n          Optional, default namespace is 'default"
        echo ""
        echo "Generate Flags:"
        echo "  --destination|-d        The destination of the integration manifests - github/s3/local. Optional, default is local"
        echo "  --path                  Mandatory when using the 'local' destination"
        echo "  --bucket                Mandatory when using the 's3' destination"
        echo "  --bucketpath            Path inside the bucket, optional. default is the root path"
        echo "  --giturl                The url of the desired repo. Mandatory when using the 'github' destination"
        echo ""
        echo "Examples:"
        echo "  cx-integrations generate --appdynamic false --appname Prod --platform kubernetes --destination s3 --bucket mybucket --fluent-bit-http"
        echo "  cx-integrations deploy --cluster dev --privatekey 1234"

        return 0
        ;;
        *)
        integration="${1}"
        ;;
    esac
    shift

  done

  if [ "$generate" = true ]; then 
    generate "$@"; 
  elif [ "$deploy" = true ]; then
    deploy "$@";
  elif [ "$apply" = true ]; then
    apply "$@"; 
  else
    echo "No command was specified, see 'cx-integrations --help'"
    exit 1
  fi

}

main "$@"
