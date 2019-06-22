upstream backend_service {
  {{ range service "web" }}
  server {{ .Address }};{{ end }}
}
