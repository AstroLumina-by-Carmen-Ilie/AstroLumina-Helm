{{/* Shared naming and label helpers. Every helper taking a service receives
a 3-item list: (service dict, color string, chart root). The `color`
argument is "" for dev (single Deployment per service, no variant label)
and "blue"/"green" for staging/production. */}}

{{/* Workload name: <service> on dev, <service>-<color> on staging/prod. */}}
{{- define "astrolumina.workloadName" -}}
{{- $svc := index . 0 -}}
{{- $color := index . 1 -}}
{{- if $color }}{{ $svc.name }}-{{ $color }}{{- else }}{{ $svc.name }}{{- end -}}
{{- end -}}

{{/* Standard object labels (metadata.labels on every namespaced object). */}}
{{- define "astrolumina.labels" -}}
{{- $svc := index . 0 -}}
{{- $color := index . 1 -}}
{{- $root := index . 2 -}}
app.kubernetes.io/name: {{ $svc.name }}
app.kubernetes.io/part-of: astrolumina
app.kubernetes.io/component: {{ $svc.component }}
environment: {{ $root.Values.environment }}
{{- if $color }}
variant: {{ $color }}
{{- end -}}
{{- end -}}

{{/* Pod selector labels (matchLabels + pod template labels). */}}
{{- define "astrolumina.selector" -}}
{{- $svc := index . 0 -}}
{{- $color := index . 1 -}}
app.kubernetes.io/name: {{ $svc.name }}
app.kubernetes.io/component: {{ $svc.component }}
{{- if $color }}
variant: {{ $color }}
{{- end -}}
{{- end -}}

{{/* Managed Secret name holding a service's env (02-secrets.yaml equivalent). */}}
{{- define "astrolumina.secretName" -}}
{{- $svc := index . 0 -}}
env-{{ $svc.name }}-secrets
{{- end -}}
