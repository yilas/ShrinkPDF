{{/* Nom de l'application */}}
{{- define "shrinkpdf.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Nom complet (inclut le nom de la release) */}}
{{- define "shrinkpdf.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels standards */}}
{{- define "shrinkpdf.labels" -}}
app.kubernetes.io/name: {{ include "shrinkpdf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Selector labels (pour le lien Service -> Deployment) */}}
{{- define "shrinkpdf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shrinkpdf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
