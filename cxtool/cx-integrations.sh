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
        aws s3 mv ./$outputdir/${integration}-manifests.yaml s3://$bucket/${integration}-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then 
          exit 1
        fi
      else
        aws s3 mv ./$outputdir/${integration}-manifests.yaml s3://$bucket/$bucketpath/${integration}-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then 
          exit 1
        else
          echo "Successfuly uploaded output manifests to s3"
          exit 0
        fi
      fi
    
    elif [ "$destination" == "github" ]; then
      if [ -z "$giturl" ]; then echo "git url is empty!"; exit 1; fi
      git clone $giturl 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
      git checkout -b integrations-manifests
      git add ./$outputdir/${integration}-manifests.yaml
      git commit -m "Adding fluent-bit-http kubernetes manifests"
      git push -u origin integrations-manifests 2>&1
      if [ $? -ne 0 ]; then 
        exit 1
      else
        echo "Successfully pushed to remote branch integrations-manifests"
        exit 0
      fi

    elif [ "$destination" == "local" ]; then
      if [ ! -z "$path" ]; then
        mv ./$outputdir/${integration}-manifests.yaml $path 2>&1
        if [ $? -ne 0 ]; then
          exit 1
        else
          echo "Successfully created manifests in $path"
        fi
      else
        echo "The generated manifests now exist under './$outputdir' directory in the current path"
      fi
    fi
  }

  function validateDynamic () {
    isdynamic=$1
    name=$2
    if [ $isdynamic == "true" ]; then #dynamic
      if [ "$integration" = "fluent-bit-http" ]; then
        if [[ $name != kubernetes.* ]]; then
          echo "$name is not valid, must start with kubernetes.*, exiting..."
          exit 1
        else
          return 0
        fi
      elif [ "$integration" = "fluentd-http" ]; then 
        if [[ $name == kubernetes.* ]]; then
          echo "$name is not valid, cannot include kubernetes in the beginning, exiting..."
          exit 1
        fi
      fi
    else #static
      if [ "$integration" = "fluent-bit-http" ]; then
        if [ -z "$name" ]; then echo "when appdynamic/subdynamic is false - the value must be specified [appname/subsystem]"; exit 1; fi
        if [[ $name == kubernetes.* ]]; then
          echo "$name is not valid, cannot start with kubernetes.*, exiting..."
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

  function helmTemplateFluentbit () {
    overridefile=$1
    if [ -z $overridefile ]; then
      helm template $integration coralogix-charts-virtual/$integration \
        --set "fluent-bit.app_name=${appname}" \
        --set "fluent-bit.sub_system=${subsystem}" \
        --set "fluent-bit.endpoint=${endpoint}" --namespace $namespace > ./$outputdir/${integration}-manifests.yaml 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
    else
      helm template $integration coralogix-charts-virtual/$integration -f $overridefile \
        --set "fluent-bit.app_name=${appname}" \
        --set "fluent-bit.sub_system=${subsystem}" \
        --set "fluent-bit.endpoint=${endpoint}" --namespace $namespace > ./$outputdir/${integration}-manifests.yaml 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
    fi
  }

  function deployHelmFluentbit () {
    overridefile=$1
    if [ -z $overridefile ]; then
      helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace \
        --set "fluent-bit.app_name=${appname}" \
        --set "fluent-bit.sub_system=${subsystem}" \
        --set "fluent-bit.endpoint=${endpoint}" 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
    else
      helm upgrade $integration coralogix-charts-virtual/$integration --install -n $namespace --create-namespace -f $overridefile \
        --set "fluent-bit.app_name=${appname}" \
        --set "fluent-bit.sub_system=${subsystem}" \
        --set "fluent-bit.endpoint=${endpoint}" 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
    fi
  }

  function switchContext () {
    if [[ ! -z "$cluster" ]]; then
      kubectl config use-context $cluster 2>&1
      if [ $? -ne 0 ]; then exit 1; fi
    fi
  }

  function privateKeySupplied () {
    if [ -z "$privatekey" ]; then
      echo "Private Key is empty! exiting..."
      exit 1
    fi
  }
  
#################################################################################################################################################
  function generate {

    if [ -z "$integration" ]; then
      echo "Integration name was not specified! exiting... "
      exit 1
    fi

    if [[ ! -d "./$outputdir" ]]; then 
      mkdir ./$outputdir
    fi

    # Generating templates for fluentbit
    if [ "$integration" = "fluent-bit-http" ] ; then
      if [ "$platform" = "kubernetes" ]; then
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=kubernetes.namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=kubernetes.container_name
        fi
        if [ $appdynamic == "true" ]; then 
          if [ $subdynamic == "true" ]; then #both dynamic
              helmTemplateFluentbit
          else
              helmTemplateFluentbit ./override-${integration}-subsystem.yaml
          fi
        elif [ $subdynamic == "true" ]; then
          helmTemplateFluentbit ./override-${integration}-appname.yaml 
        else #both static
          helmTemplateFluentbit ./override-${integration}-static.yaml
        fi
      else
        echo "Platform must be kubernetes, exiting..."
        exit 1
      fi
    fi

    # Generating templates for fluentd-http
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "kubernetes" ]; then
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=container_name
        fi
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
          --set "fluentd.env[8].name=K8S_NODE_NAME" --set "fluentd.env[8].valueFrom.fieldRef.fieldPath=spec.nodeName" \
          --namespace $namespace > ./$outputdir/${integration}-manifests.yaml 2>&1
        if [ $? -ne 0 ]; then exit 1; fi
      else
        echo "Platform must be kubernetes, exiting..."
        exit 1
      fi
    fi
  
    upload $destination
    
  } 

#################################################################################################################################################
  function deploy {

    switchContext $cluster
    privateKeySupplied $privatekey
    check_secret_exists

    # Deploying Fluent-Bit
    if [ "$integration" = "fluent-bit-http" ]; then
      if [ $platform == "kubernetes" ]; then
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=kubernetes.namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=kubernetes.container_name
        fi
        if [ $appdynamic == "true" ]; then 
          if [ $subdynamic == "true" ]; then
              deployHelmFluentbit
          else
              deployHelmFluentbit ./override-${integration}-subsystem.yaml
          fi
        elif [ $subdynamic == "true" ]; then
          deployHelmFluentbit ./override-${integration}-appname.yaml
        else
          deployHelmFluentbit ./override-${integration}-static.yaml
        fi
      else
        echo "Platform must be kubernetes, exiting..."
        exit 1     
      fi
    fi 

    # Deploying Fluentd-http
    # Fluentd doesnt support 'envwithtpl' like Fluentbit, meaning it doesn't template the configuration,
    # so the overrides must be set like the following, and include all of the environment variables, even if they are similar to the defaults :
    if [ "$integration" = "fluentd-http" ]; then
      if [ $platform == "kubernetes" ]; then
        if [ -z "$appname" ] && [ "$appdynamic" == "true" ]; then 
          appname=namespace_name
        fi
        if [ -z "$subsystem" ] && [ "$subdynamic" == "true" ]; then 
          subsystem=container_name
        fi
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
      else
        echo "Platform must be kubernetes, exiting..."
        exit 1
      fi
    fi   
  }

#################################################################################################################################################
  function apply { 

    switchContext $cluster
    generate "$@";
    echo "Applying manifests..."
    privateKeySupplied $privatekey
    check_secret_exists
    kubectl apply -f ./$outputdir/${integration}-manifests.yaml -n $namespace
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

  if [ "$integration" != "fluent-bit-http" ] && [ "$integration" != "fluentd-http" ]; then 
    echo "Integration chart name is not valid"
    exit 1
  fi
  helmInstalled 
  validateDynamic ${appdynamic} ${appname}
  validateDynamic ${subdynamic} ${subsystem}
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
