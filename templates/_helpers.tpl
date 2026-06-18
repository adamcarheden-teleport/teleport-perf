{{- define "tperf.test-runner-name" -}}
{{- printf "%s-test-runner" .Release.Name -}}
{{- end }}

{{- define "tperf.target-name" -}}
{{- printf "%s-target" .Release.Name -}}
{{- end }}

{{- define "tperf.sa-name" -}}
{{- printf "%s" .Release.Name -}}
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
{{- include "tperf.sa-name" . -}}
{{- end }}
