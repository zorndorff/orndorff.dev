---
title: "Root"
date: 2018-03-08T13:32:25-06:00
draft: false
menu: "main"
layout: "single"

---

Hi , I'm Zac.

A Chicago software engineer.

I love experimenting with new technology and applying the lessons learned to my daily work.

Follow my projects here.
{{ $paginator := .Paginate (where .Data.Pages "Type" "posts") }}
{{ range $paginator.Pages }}

  {{ partial "summary.html" . }}
{{ end }}
{{ partial "pagination.html" . }}

