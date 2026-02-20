#let px(value) = value * 0.75pt

#let _font_stacks = (
  nsm: ("DejaVu Sans Mono"),
  ns: ("DejaVu Sans"),
  ser: ("DejaVu Serif"),
  atk: ("DejaVu Sans"),
  ibm: ("DejaVu Sans Mono"),
)

#let _font_stack(font-id) = {
  if font-id in _font_stacks {
    _font_stacks.at(font-id)
  } else {
    _font_stacks.at("nsm")
  }
}

#let _layout_profile(placement) = {
  if placement == "left" {
    (text_x: px(104), text_y: px(0), text_w: px(200), text_h: px(224), artifacts_x: px(0), artifacts_y: px(0), artifacts_w: px(96), artifacts_h: px(224), max_lines: 12, max_artifacts: 2, show_caption: true)
  } else if placement == "top" {
    (text_x: px(0), text_y: px(104), text_w: px(304), text_h: px(120), artifacts_x: px(0), artifacts_y: px(0), artifacts_w: px(304), artifacts_h: px(96), max_lines: 6, max_artifacts: 3, show_caption: false)
  } else if placement == "bottom" {
    (text_x: px(0), text_y: px(0), text_w: px(304), text_h: px(120), artifacts_x: px(0), artifacts_y: px(128), artifacts_w: px(304), artifacts_h: px(96), max_lines: 6, max_artifacts: 3, show_caption: false)
  } else if placement == "none" {
    (text_x: px(0), text_y: px(0), text_w: px(304), text_h: px(224), artifacts_x: px(0), artifacts_y: px(0), artifacts_w: px(0), artifacts_h: px(0), max_lines: 12, max_artifacts: 0, show_caption: false)
  } else {
    (text_x: px(0), text_y: px(0), text_w: px(200), text_h: px(224), artifacts_x: px(208), artifacts_y: px(0), artifacts_w: px(96), artifacts_h: px(224), max_lines: 12, max_artifacts: 2, show_caption: true)
  }
}

#let _artifact_box(artifact, show-caption: true) = {
  let caption = if show-caption {
    artifact.kind + ": " + artifact.label
  } else {
    ""
  }
  box(width: px(96), height: if show-caption { px(112) } else { px(96) }, inset: 0pt)[
    #rect(width: px(96), height: px(96), fill: rgb("ffffff"), stroke: rgb("c6cec7"))
    #place(top + left, dx: px(18), dy: px(18))[#rect(width: px(60), height: px(60), fill: rgb("0f120f"))]
    #if show-caption [
      #place(top + left, dy: px(99))[
        #box(width: px(96), inset: 0pt)[
          #set text(font: ("DejaVu Sans Mono"), size: px(10), fill: rgb("4b5e54"))
          #caption
        ]
      ]
    ]
  ]
}

#let _content_lines(lines, font-id, max-lines) = {
  let fitted = lines.slice(0, calc.min(max-lines, lines.len()))
  box(inset: 0pt, width: 100%, height: 100%)[
    #set text(font: _font_stack(font-id), size: px(16), fill: rgb("1f2520"))
    #set par(leading: px(2))
    #for line in fitted [
      #line
      \
    ]
  ]
}

#let _first_capture(match, a, b: none) = {
  let first = match.captures.at(a)
  if first != none {
    first
  } else if b != none {
    match.captures.at(b)
  } else {
    none
  }
}

#let _trim_url(url) = {
  if url.len() == 0 {
    url
  } else if (
    url.ends-with(".") or
    url.ends-with(",") or
    url.ends-with("!") or
    url.ends-with("?") or
    url.ends-with(";") or
    url.ends-with(":") or
    url.ends-with(")") or
    url.ends-with("]")
  ) {
    _trim_url(url.slice(0, url.len() - 1))
  } else {
    url
  }
}

#let parse-message(
  message,
  default-font: "nsm",
  default-placement: "right",
) = {
  let font-re = regex("^#font\\(\\s*(?:\"([A-Za-z0-9_-]+)\"|([A-Za-z0-9_-]+))\\s*\\)$")
  let place-re = regex("^#place\\(\\s*(?:\"([A-Za-z]+)\"|([A-Za-z]+))\\s*\\)$")
  let qr-re = regex("^#qr\\(\\s*\"([^\"]+)\"\\s*\\)$")
  let event-re = regex("^#event\\(\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]+)\"(?:\\s*,\\s*\"([^\"]*)\")?\\s*\\)$")
  let contact-re = regex("^#contact\\(\\s*\"([^\"]+)\"(?:\\s*,\\s*\"([^\"]*)\")?(?:\\s*,\\s*\"([^\"]*)\")?(?:\\s*,\\s*\"([^\"]*)\")?\\s*\\)$")
  let url-re = regex("https?://[^\\s<>()\"'`]+")

  let lines = ()
  let artifacts = ()
  let seen = (:)
  let settings = (font_id: default-font, placement: default-placement)

  for raw-line in message.split("\n") {
    let line = raw-line.trim()

    let font-match = line.match(font-re)
    if font-match != none {
      let token = _first_capture(font-match, 0, b: 1)
      if token != none {
        settings.insert("font_id", token)
      }
      continue
    }

    let place-match = line.match(place-re)
    if place-match != none {
      let place-token = _first_capture(place-match, 0, b: 1)
      if place-token != none {
        let candidate = place-token
        if candidate == "float" or candidate == "auto" or candidate == "default" {
          settings.insert("placement", "right")
        } else if candidate == "off" or candidate == "hidden" {
          settings.insert("placement", "none")
        } else if candidate == "right" or candidate == "left" or candidate == "top" or candidate == "bottom" or candidate == "none" {
          settings.insert("placement", candidate)
        }
      }
      continue
    }

    let qr-match = line.match(qr-re)
    if qr-match != none {
      let payload = _first_capture(qr-match, 0)
      if payload != none {
        let key = "qr::" + payload
        if not (key in seen) {
          seen.insert(key, true)
          artifacts.push((kind: "qr", label: payload))
        }
      }
      continue
    }

    let event-match = line.match(event-re)
    if event-match != none {
      let title = _first_capture(event-match, 1)
      if title != none {
        let key = "event::" + title
        if not (key in seen) {
          seen.insert(key, true)
          artifacts.push((kind: "event", label: title))
        }
      }
      continue
    }

    let contact-match = line.match(contact-re)
    if contact-match != none {
      let name = _first_capture(contact-match, 0)
      if name != none {
        let key = "contact::" + name
        if not (key in seen) {
          seen.insert(key, true)
          artifacts.push((kind: "contact", label: name))
        }
      }
      continue
    }

    for url-match in raw-line.matches(url-re) {
      let url = _trim_url(url-match.text)
      if url.len() > 0 {
        let key = "url::" + url
        if not (key in seen) {
          seen.insert(key, true)
          artifacts.push((kind: "url", label: url))
        }
      }
    }

    lines.push(raw-line)
  }

  (
    lines: lines,
    artifacts: artifacts,
    font_id: settings.at("font_id"),
    placement: settings.at("placement"),
  )
}

#let render-message-window(
  message,
  default-font: "nsm",
  default-placement: "right",
) = {
  let parsed = parse-message(
    message,
    default-font: default-font,
    default-placement: default-placement,
  )
  let profile = _layout_profile(parsed.placement)
  let artifact-items = parsed.artifacts.slice(0, calc.min(profile.max_artifacts, parsed.artifacts.len()))
  let artifact-spacing = px(8)

  set page(width: px(320), height: px(240), margin: 0pt)
  box(width: px(320), height: px(240), inset: 0pt)[
    #rect(width: px(320), height: px(240), fill: rgb("f8faf8"))
    #place(top + left, dx: px(8), dy: px(8))[
      #box(width: px(304), height: px(224), inset: 0pt)[
        #place(top + left, dx: profile.text_x, dy: profile.text_y)[
          #box(width: profile.text_w, height: profile.text_h, inset: 0pt)[
            #_content_lines(parsed.lines, parsed.font_id, profile.max_lines)
          ]
        ]
        #if artifact-items.len() > 0 and profile.max_artifacts > 0 [
          #place(top + left, dx: profile.artifacts_x, dy: profile.artifacts_y)[
            #box(width: profile.artifacts_w, height: profile.artifacts_h, inset: 0pt)[
              #stack(
                dir: if parsed.placement == "top" or parsed.placement == "bottom" { ltr } else { ttb },
                spacing: artifact-spacing,
                ..artifact-items.map(item => _artifact_box(item, show-caption: profile.show_caption))
              )
            ]
          ]
        ]
      ]
    ]
  ]
}
