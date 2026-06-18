{{- define "tperf.test-runner-name" -}}
{{- printf "%s-test-runner" .Release.Name -}}
{{- end }}

{{- define "tperf.target-name" -}}
{{- printf "%s-target" .Release.Name -}}
{{- end }}

{{- define "tperf.sa-name" -}}
{{- printf "%s" .Release.Name -}}
{{- end }}