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

#let _module(x, y, size, fill) = {
  _builtin_place(top + left, dx: x * size, dy: y * size)[
    #rect(width: size, height: size, fill: fill)
  ]
}

#let _in_range(v, start, finish) = v >= start and v <= finish

#let _in_finder(x, y, ox, oy) = _in_range(x, ox, ox + 6) and _in_range(y, oy, oy + 6)

#let _finder(x, y, size) = {
  box(width: size * 7, height: size * 7, inset: 0pt)[
    #rect(width: size * 7, height: size * 7, fill: rgb("111111"))
    #_builtin_place(top + left, dx: size, dy: size)[
      #rect(width: size * 5, height: size * 5, fill: rgb("ffffff"))
    ]
    #_builtin_place(top + left, dx: size * 2, dy: size * 2)[
      #rect(width: size * 3, height: size * 3, fill: rgb("111111"))
    ]
  ]
}

#let qr(url) = {
  let size = px(2)
  let dim = 29
  let seed = url.len()
  box(width: px(64), height: px(64), inset: 0pt)[
    #rect(width: px(64), height: px(64), fill: rgb("ffffff"))
    #_builtin_place(top + left, dx: px(3), dy: px(3))[
      #box(width: size * dim, height: size * dim, inset: 0pt)[
        #for y in range(0, dim) [
          #for x in range(0, dim) [
            #if not (
              _in_finder(x, y, 0, 0) or
              _in_finder(x, y, 22, 0) or
              _in_finder(x, y, 0, 22)
            ) and (calc.rem(x * 11 + y * 7 + seed, 5) <= 1) [
              #_module(x, y, size, rgb("111111"))
            ]
          ]
        ]
        #_builtin_place(top + left, dx: 0pt, dy: 0pt)[#_finder(0, 0, size)]
        #_builtin_place(top + left, dx: size * 22, dy: 0pt)[#_finder(0, 0, size)]
        #_builtin_place(top + left, dx: 0pt, dy: size * 22)[#_finder(0, 0, size)]
      ]
    ]
  ]
}

#let place(loc, body) = align(loc, body)

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
