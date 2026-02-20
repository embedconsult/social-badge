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

#let render-badge(
  lines: (),
  artifacts: (),
  trust: "UNVERIFIED",
  author: "Demo Peer",
  stamp: "now",
  font-id: "nsm",
  placement: "right",
) = {
  let profile = _layout_profile(placement)
  let artifact-items = artifacts.slice(0, calc.min(profile.max_artifacts, artifacts.len()))
  let artifact-spacing = if placement == "top" or placement == "bottom" { px(8) } else { px(8) }

  set page(width: px(400), height: px(300), margin: 0pt)
  box(width: px(400), height: px(300), inset: 0pt)[
    #rect(width: px(400), height: px(300), fill: rgb("d9dfd8"), stroke: rgb("506357"), radius: px(4))

    #place(top + left)[#rect(width: px(400), height: px(24), fill: rgb("eff3ef"), stroke: rgb("9bab9f"))]
    #place(top + left, dy: px(264))[#rect(width: px(400), height: px(36), fill: rgb("eff3ef"), stroke: rgb("9bab9f"))]

    #place(top + left, dy: px(24))[#rect(width: px(40), height: px(240), fill: rgb("e4eae3"), stroke: rgb("9bab9f"))]
    #place(top + left, dx: px(360), dy: px(24))[#rect(width: px(40), height: px(240), fill: rgb("e4eae3"), stroke: rgb("9bab9f"))]

    #place(top + left, dx: px(40), dy: px(24))[#rect(width: px(320), height: px(240), fill: rgb("f8faf8"), stroke: rgb("9bab9f"))]

    #place(top + left, dx: px(8), dy: px(7))[
      #set text(font: ("DejaVu Sans Mono"), size: px(11), fill: rgb("1f2520"))
      #trust
    ]
    #place(top + left, dx: px(160), dy: px(7))[
      #set text(font: ("DejaVu Sans Mono"), size: px(11), fill: rgb("1f2520"))
      #author
    ]
    #place(top + left, dx: px(370), dy: px(7))[
      #set text(font: ("DejaVu Sans Mono"), size: px(11), fill: rgb("1f2520"))
      #stamp
    ]

    #place(top + left, dx: px(48), dy: px(32))[
      #box(width: px(304), height: px(224), inset: 0pt)[
        #place(top + left, dx: profile.text_x, dy: profile.text_y)[
          #box(width: profile.text_w, height: profile.text_h, inset: 0pt)[
            #_content_lines(lines, font-id, profile.max_lines)
          ]
        ]
        #if artifact-items.len() > 0 and profile.max_artifacts > 0 [
          #place(top + left, dx: profile.artifacts_x, dy: profile.artifacts_y)[
            #box(width: profile.artifacts_w, height: profile.artifacts_h, inset: 0pt)[
              #stack(
                dir: if placement == "top" or placement == "bottom" { ltr } else { ttb },
                spacing: artifact-spacing,
                ..artifact-items.map(item => _artifact_box(item, show-caption: profile.show_caption))
              )
            ]
          ]
        ]
      ]
    ]

    #place(top + left, dx: px(165), dy: px(277))[
      #set text(font: ("DejaVu Sans Mono"), size: px(11), fill: rgb("1f2520"))
      [fixed 320x240]
    ]
  ]
}
