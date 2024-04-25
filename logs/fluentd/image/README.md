# Coralogix Fluentd Daemon Set Image:

This folder contains the docker file for the image Coralogix promotes along with it's Daemon Set.

## Image base

This image is based on the open source image:
`fluent/fluentd-kubernetes-daemonset:v1.16.5-debian-forward-1.0`

Supported plugin List:

| Plugin Name                              | Plugin Project URL                                                       |
|------------------------------------------|--------------------------------------------------------------------------|
| fluent-plugin-coralogix                  | (https://rubygems.org/gems/fluent-plugin-coralogix)                      |
| fluent-plugin-prometheus                 | (https://github.com/fluent/fluent-plugin-prometheus)                     |
| fluent-plugin-parser-cri                 | (https://github.com/fluent/fluent-plugin-parser-cri)                     |
| fluent-plugin-kubernetes_metadata_filter | (https://github.com/fabric8io/fluent-plugin-kubernetes_metadata_filter)  |
| fluent-plugin-sampling-filter            | (https://github.com/tagomoris/fluent-plugin-sampling-filter)             |
| fluent-plugin-concat                     | (https://github.com/fluent-plugins-nursery/fluent-plugin-concat)         |
| fluent-plugin-rewrite-tag-filter         | (https://github.com/fluent/fluent-plugin-rewrite-tag-filter)             |
| fluent-plugin-detect-exceptions          | (https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions) |
| fluent-plugin-elasticsearch              | (https://github.com/uken/fluent-plugin-elasticsearch)                    |
