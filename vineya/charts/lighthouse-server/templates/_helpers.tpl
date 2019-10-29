{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "lighthouse-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "lighthouse-server.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "lighthouse-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "lighthouse-server.env" }}
env:
  - name: DOMAIN_NAME
    value: {{ .Values.global.publicDomain }}
  - name: STACK_NAME
    value: {{ .Values.global.color }}
  - name: RAILS_ENV
    value: {{ .Values.railsEnv }}
  - name: EJSON_ENV
    value: {{ .Values.ejsonEnv }}
  - name: EJSON_PRIVATE_KEY
    valueFrom:
      secretKeyRef:
        name: {{ template "lighthouse-server.name" . }}
        key: EJSON_PRIVATE_KEY
  {{- if .Values.postgresql.enabled }}
  - name: DATABASE_URL
    value: "postgres://{{ .Values.postgresql.postgresUser }}:{{ .Values.postgresql.postgresPassword }}@{{ template "postgresql.fullname" . }}:5432"
  {{- end }}
  {{- if .Values.redis.enabled }}
  - name: REDIS_URL
    value: "redis://{{ template "redis.fullname" . }}:6379/0"
  {{- else }}
  - name: REDIS_URL
    value: "redis://localhost:6379/0"
  {{- end }}
  {{- if .Values.rabbitmq.enabled }}
  - name: RABBITMQ_URL
    value: "amqp://{{ .Values.rabbitmq.rabbitmqUsername }}:{{ .Values.rabbitmq.rabbitmqPassword }}@{{ template "rabbitmq.fullname" . }}:5672"
  {{- end }}
{{- end -}}

{{- define "lighthouse-redis-stunnel-container" }}
- name: redis-stunnel
  image: csd1/stunnel:latest
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  args: ["/etc/stunnel/stunnel.conf"]
  env:
    - name: CONNECT_ADDRESS
      value: "{{ .Values.global.redis.host }}:{{ .Values.global.redis.port }}"
  resources:
    requests:
      cpu: 20m
{{- end -}}

{{- define "lighthouse-server.affinity" }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
      matchExpressions:
        - key: app
          operator: In
          values:
            - {{ template "lighthouse-server.name" . }}-carrot-rpc
      topologyKey: "kubernetes.io/hostname"
{{- end -}}