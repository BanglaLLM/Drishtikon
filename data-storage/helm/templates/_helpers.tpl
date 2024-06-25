{{/*
Expand the name of the chart.
*/}}
{{- define "data-storage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "data-storage.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" (include "data-storage.name" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create the default chart labels.
*/}}
{{- define "data-storage.labels" -}}
helm.sh/chart: {{ include "data-storage.chart" . }}
{{ include "data-storage.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Create the default selector labels.
*/}}
{{- define "data-storage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "data-storage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Expand the chart name and version.
*/}}
{{- define "data-storage.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
