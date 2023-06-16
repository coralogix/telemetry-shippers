# ** THIS IMAGE IS DEPRECATED AS WE NO LONGER SUPPORT THE FLUENT-PLUGIN-CORALOGIX PLUGIN, PLEASE USE HTTP WITH THE [OFFICIAL FLUENTD IMAGE](https://hub.docker.com/r/fluent/fluentd) **


# Coralogix Fluentd Standalone Image:

This folder contains the docker file for the image including the Coralogix plugin (and others).

## Image base

This image is based on the open source image:
`fluent/fluentd:v1.14.0-debian-1.0`

Supported plugin List:

| Plugin Name                              | Plugin Project URL                                                       |
|------------------------------------------|--------------------------------------------------------------------------|
| fluent-plugin-coralogix                  | (https://rubygems.org/gems/fluent-plugin-coralogix)                      |
| fluent-plugin-prometheus                 | (https://github.com/fluent/fluent-plugin-prometheus)                     |
| fluent-plugin-parser-cri                 | (https://github.com/fluent/fluent-plugin-parser-cri)                     |
| fluent-plugin-sampling-filter            | (https://github.com/tagomoris/fluent-plugin-sampling-filter)             |
| fluent-plugin-concat                     | (https://github.com/fluent-plugins-nursery/fluent-plugin-concat)         |
| fluent-plugin-rewrite-tag-filter         | (https://github.com/fluent/fluent-plugin-rewrite-tag-filter)             |
| fluent-plugin-detect-exceptions          | (https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions) |
| fluent-plugin-redis-store              | (https://github.com/pokehanai/fluent-plugin-redis-store)                    |
