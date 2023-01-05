
{{- define "prometheus-agent.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 26 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 26 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 26 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Prometheus custom resource instance name */}}
{{- define "prometheus-agent.name" -}}
{{- print (include "prometheus-agent.fullname" .) "" }}
{{- end }}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "prometheus-agent.namespace" -}}
  {{- if .Values.namespace -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/* Create the name of prometheus service account to use */}}
{{- define "prometheus-agent.serviceAccountName" -}}
{{- if .Values.prometheus.prometheusSpec.serviceAccountName -}}
    {{ default (print (include "prometheus-agent.fullname" .) "") .Values.prometheus.prometheusSpec.serviceAccountName }}
{{- else -}}
    {{ default "default" .Values.prometheus.prometheusSpec.serviceAccountName }}
{{- end -}}
{{- end -}}