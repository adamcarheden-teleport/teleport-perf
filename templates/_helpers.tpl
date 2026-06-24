{{- define "tperf.test-runner-name" -}}
{{- printf "%s-test-runner" .Release.Name -}}
{{- end }}

{{- define "tperf.target-name" -}}
{{- printf "%s-target" .Release.Name -}}
{{- end }}

{{- define "tperf.sa-name" -}}
{{- required "Please set tbot.serviceAccount.name to the shared ServiceAccount name for this chart" .Values.tbot.serviceAccount.name -}}
{{- end }}

{{- define "tperf.scripts" -}}
{{- printf "%s-scripts" .Release.Name -}}
{{- end }}

{{- define "tperf.group" -}}
{{- required "Please set 'group' to the Group assigned to the bot by your Teleport role" .Values.group -}}
{{- end }}

# We override this sub-chart template to set our service acount name so the
# user doesn't have to make strings match
{{- define "tbot.serviceAccountName" -}}
{{- required "Please set serviceAccount.name for the tbot chart" .Values.serviceAccount.name -}}
{{- end }}

{{- define "tperf.results-dir" -}}
{{- printf "/results" -}}
{{- end }}


{{- define "tperf.common-labels" -}}
app.kubernetes.io/name: {{ .Values.app_name | default "tperf" }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "tperf.target-labels" -}}
{{ include "tperf.common-labels" . }}
app.kubernetes.io/component: target
{{- end }}

{{- define "tperf.runner-labels" -}}
{{ include "tperf.common-labels" . }}
app.kubernetes.io/component: test-runner
{{- end }}
