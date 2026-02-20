#let px(value) = value * 0.75pt

#let _font_stacks = (
  nsm: ("DejaVu Sans Mono"),
  ns: ("DejaVu Sans"),
  ser: ("DejaVu Serif"),
  atk: ("DejaVu Sans"),
  ibm: ("DejaVu Sans Mono"),
)

#let _font_stack(font_id) = {
  if font_id in _font_stacks {
    _font_stacks.at(font_id)
  } else {
    _font_stacks.at("nsm")
  }
}

#let _builtin_place = place
#import "../vendor/tiaoma/lib.typ": qrcode

#let qr(url) = {
  box(width: px(64), height: px(64), inset: 0pt)[
    #rect(width: px(64), height: px(64), fill: rgb("ffffff"))
    #_builtin_place(top + left)[
      #qrcode(
        url,
        width: px(64),
        height: px(64),
        options: (
          fg-color: rgb("111111"),
          bg-color: rgb("ffffff"),
        ),
      )
    ]
  ]
}

#let place(loc, body) = _builtin_place(loc)[#body]

#let render-message-window(
  body,
  font_id: "nsm",
) = {
  set page(width: px(320), height: px(240), margin: 0pt)
  box(width: px(320), height: px(240), inset: 0pt)[
    #rect(width: px(320), height: px(240), fill: rgb("f8faf8"))
    #_builtin_place(top + left, dx: px(8), dy: px(8))[
      #box(width: px(304), height: px(224), inset: 0pt, clip: true)[
        #set text(font: _font_stack(font_id), size: px(16), fill: rgb("1f2520"))
        #set par(leading: px(2))
        #body
      ]
    ]
  ]
}
