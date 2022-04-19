## CX-Integrations CLI

The easiest way to generate integrations manifests and deploy an integration on Kubernetes with/without Helm. 
Currently the supported integrations are Fluentd-http and Fluent-bit-http.

### Installation 
```
git clone git@github.com:coralogix/eng-integrations.git 
vim ~/.zshrc
export PATH=$PATH:/eng-integrations/cxtool
source ~/.zshrc
```

### Usage
```
  cx-integrations [Command] [Flags] integration

Available integrations:
  fluentd-http, fluent-bit-http

Commands:
  generate                Generating manifests for the desired integration and sending it to the desired destination.
  deploy                  Deploying desired integration with Helm.
  apply                   Deploying desired integration to Kubernetes without Helm.

Common Flags:
  --endpoint|-e           Optional, Coralogix default endpoint is 'api.eu2.coralogix.com'.
  --appname               Optional, default is kubernetes namespace name.
  --subsystem             Optional, default is kubernetes container name.
  --appdynamic            Default is true, if changing the appname to static, this flag is mandatory and must be set to false.
  --subdynamic            Default is true, if changing the subsystem to static, this flag is mandatory and must be set to false.
  --platform              The platform to generate/deploy for, currently the available platform is kubernetes

Deploy Flags:
  --privatekey            Mandatory, the 'send-your-logs' key
  --cluster               Optional, the name of the kubernetes cluster to deploy in. Default is the current context
  --namespace|-n          Optional, default namespace is 'default

Apply Flags:
  --privatekey            Mandatory, the 'send-your-logs' key
  --cluster               Optional, the name of the kubernetes cluster to deploy in. Default is the current context
  --namespace|-n          Optional, default namespace is 'default

Generate Flags:
  --destination|-d        The destination of the integration manifests - github/s3/local. Optional, default is local
  --path                  Mandatory when using the 'local' destination
  --bucket                Mandatory when using the 's3' destination
  --bucketpath            Path inside the bucket, optional. default is the root path
  --giturl                The url of the desired repo. Mandatory when using the 'github' destination

Examples:
  cx-integrations generate --appdynamic false --appname Prod --destination s3 --bucket mybucket fluent-bit-http
  cx-integrations deploy --privatekey a1234b fluentd-http
  cx-integrations apply --privatekey a1234b -n monitoring fluentd-http
```