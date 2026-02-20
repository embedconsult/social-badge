require "json"
require "./models"

module SocialBadge
  class AuthoringPageService
    MAX_CHARS      = Message::MAX_BODY_LENGTH
    PREVIEW_SCRIPT = {{ read_file("#{__DIR__}/authoring_preview.js") }}

    FONT_PROFILES = [
      {
        id:        "noto-sans-mono",
        short_id:  "nsm",
        label:     "Noto Sans Mono",
        css_stack: "\"Noto Sans Mono\", \"Liberation Mono\", \"DejaVu Sans Mono\", monospace",
      },
      {
        id:        "noto-sans",
        short_id:  "ns",
        label:     "Noto Sans",
        css_stack: "\"Noto Sans\", \"Liberation Sans\", \"DejaVu Sans\", sans-serif",
      },
      {
        id:        "noto-serif",
        short_id:  "ser",
        label:     "Noto Serif",
        css_stack: "\"Noto Serif\", \"Liberation Serif\", \"DejaVu Serif\", serif",
      },
      {
        id:        "atkinson",
        short_id:  "atk",
        label:     "Atkinson Hyperlegible",
        css_stack: "\"Atkinson Hyperlegible\", \"Noto Sans\", \"Liberation Sans\", sans-serif",
      },
      {
        id:        "ibm-plex-mono",
        short_id:  "ibm",
        label:     "IBM Plex Mono",
        css_stack: "\"IBM Plex Mono\", \"Noto Sans Mono\", \"Liberation Mono\", monospace",
      },
    ] of NamedTuple(id: String, short_id: String, label: String, css_stack: String)

    def render(identity : Identity) : String
      config_json = {
        max_chars:       MAX_CHARS,
        author_name:     identity.display_name,
        trust_level:     identity.trust_level.to_s,
        font_profiles:   FONT_PROFILES,
        default_font_id: FONT_PROFILES.first[:id],
      }.to_json.gsub("</", "<\\/")

      <<-HTML
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Social Badge Composer</title>
        <style>
          :root {
            --bg: #f2f4ef;
            --panel: #ffffff;
            --ink: #1f2520;
            --muted: #5f6d63;
            --accent: #2f6f5f;
            --edge: #c3ccc4;
            --preview-font-family: "Noto Sans Mono", "Liberation Mono", "DejaVu Sans Mono", monospace;
          }

          * { box-sizing: border-box; }

          body {
            margin: 0;
            font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Palatino, serif;
            color: var(--ink);
            background: radial-gradient(circle at 12% 18%, #ffffff 0%, var(--bg) 58%, #dce2db 100%);
            min-height: 100vh;
          }

          .wrap {
            width: min(1240px, 100% - 32px);
            margin: 24px auto 40px;
            display: grid;
            gap: 20px;
            grid-template-columns: minmax(320px, 430px) minmax(430px, 1fr);
          }

          .card {
            background: var(--panel);
            border: 1px solid var(--edge);
            border-radius: 14px;
            padding: 16px;
            box-shadow: 0 8px 26px rgba(28, 44, 36, 0.08);
          }

          h1 {
            margin: 0 0 8px;
            font-size: 1.4rem;
            letter-spacing: 0.01em;
          }

          p {
            margin: 0 0 12px;
            color: var(--muted);
          }

          textarea {
            width: 100%;
            min-height: 260px;
            resize: vertical;
            border: 1px solid var(--edge);
            border-radius: 10px;
            padding: 12px;
            font: 16px/1.45 "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Palatino, serif;
            color: var(--ink);
            background: #fff;
          }

          textarea:focus {
            outline: 2px solid #87b2a6;
            outline-offset: 1px;
          }

          .toolbar {
            margin-top: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
          }

          .meta {
            color: var(--muted);
            font-size: 0.95rem;
          }

          .controls {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
          }

          label {
            font-size: 0.9rem;
            color: var(--muted);
          }

          select {
            border: 1px solid var(--edge);
            border-radius: 8px;
            padding: 6px 8px;
            font-size: 0.95rem;
            background: #fff;
            color: var(--ink);
          }

          button {
            border: 1px solid #315e53;
            background: var(--accent);
            color: #f5fbf8;
            border-radius: 8px;
            padding: 8px 12px;
            font-weight: 600;
            cursor: pointer;
          }

          button[disabled] {
            opacity: 0.45;
            cursor: default;
          }

          .secondary {
            background: #eef3ef;
            color: var(--ink);
            border-color: var(--edge);
          }

          .publish-status {
            font-size: 0.95rem;
            color: var(--muted);
            min-height: 1.3em;
          }

          .preview-status {
            margin-top: 8px;
            font-size: 0.9rem;
            color: #7a2d2d;
            min-height: 1.2em;
          }

          .badge-frame {
            width: 400px;
            height: 300px;
            position: relative;
            margin: 0 auto;
            border: 2px solid #506357;
            border-radius: 6px;
            overflow: hidden;
            background: #d9dfd8;
          }

          .chrome-top {
            position: absolute;
            left: 0;
            top: 0;
            width: 400px;
            height: 24px;
            border-bottom: 1px solid #9bab9f;
            background: #eff3ef;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 8px;
            font: 11px/1 "Menlo", "SFMono-Regular", "Consolas", monospace;
          }

          .chrome-bottom {
            position: absolute;
            left: 0;
            top: 264px;
            width: 400px;
            height: 36px;
            border-top: 1px solid #9bab9f;
            background: #eff3ef;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            font: 11px/1 "Menlo", "SFMono-Regular", "Consolas", monospace;
          }

          .gutter-left {
            position: absolute;
            left: 0;
            top: 24px;
            width: 40px;
            height: 240px;
            border-right: 1px solid #9bab9f;
            background: #e4eae3;
          }

          .gutter-right {
            position: absolute;
            left: 360px;
            top: 24px;
            width: 40px;
            height: 240px;
            border-left: 1px solid #9bab9f;
            background: #e4eae3;
          }

          .viewport {
            position: absolute;
            left: 40px;
            top: 24px;
            width: 320px;
            height: 240px;
            background: #f8faf8;
          }

          .message-box {
            position: absolute;
            left: 48px;
            top: 32px;
            width: 304px;
            height: 224px;
            z-index: 1;
            overflow: hidden;
            display: grid;
            grid-template-columns: 1fr;
            column-gap: 8px;
            align-content: stretch;
            font-size: 16px;
            line-height: 18px;
            font-family: var(--preview-font-family);
            color: #1f2520;
            user-select: text;
          }

          .typst-render {
            position: absolute;
            left: 48px;
            top: 32px;
            width: 304px;
            height: 224px;
            z-index: 2;
            overflow: hidden;
            pointer-events: none;
          }

          .typst-render svg {
            display: block;
            width: 304px;
            height: 224px;
          }

          .message-box.with-artifacts {
            column-gap: 8px;
          }

          .message-text {
            overflow: hidden;
          }

          .message-artifacts {
            display: none;
            align-content: start;
            justify-content: start;
            gap: 8px;
            overflow: hidden;
          }

          .message-box.with-artifacts .message-artifacts {
            display: grid;
          }

          .message-box.with-artifacts-right {
            grid-template-columns: 200px 96px;
          }

          .message-box.with-artifacts-right .message-text {
            order: 1;
          }

          .message-box.with-artifacts-right .message-artifacts {
            order: 2;
          }

          .message-box.with-artifacts-left {
            grid-template-columns: 96px 200px;
          }

          .message-box.with-artifacts-left .message-artifacts {
            order: 1;
          }

          .message-box.with-artifacts-left .message-text {
            order: 2;
          }

          .message-box.with-artifacts-top {
            grid-template-columns: 1fr;
            grid-template-rows: 96px 120px;
            row-gap: 8px;
          }

          .message-box.with-artifacts-top .message-artifacts {
            order: 1;
            grid-auto-flow: column;
            grid-auto-columns: 96px;
            justify-content: start;
          }

          .message-box.with-artifacts-top .message-text {
            order: 2;
          }

          .message-box.with-artifacts-bottom {
            grid-template-columns: 1fr;
            grid-template-rows: 120px 96px;
            row-gap: 8px;
          }

          .message-box.with-artifacts-bottom .message-text {
            order: 1;
          }

          .message-box.with-artifacts-bottom .message-artifacts {
            order: 2;
            grid-auto-flow: column;
            grid-auto-columns: 96px;
            justify-content: start;
          }

          .message-artifact-inline {
            width: 96px;
            height: 96px;
            margin: 0;
          }

          .message-artifact-inline img {
            width: 96px;
            height: 96px;
            border: 1px solid #c6cec7;
            background: #fff;
          }

          .line {
            height: 18px;
            white-space: pre;
          }

          .line.heading-1,
          .line.heading-2,
          .line.heading-3 {
            font-weight: 700;
          }

          .line.heading-1 { letter-spacing: 0.02em; }
          .line.quote { color: #31443a; }
          .line.code {
            background: #eff3ef;
            border-left: 2px solid #9bab9f;
            padding-left: 4px;
          }
          .line.hr {
            color: #6c7b71;
          }
          .line.table {
            color: #2d3a32;
            font-weight: 600;
          }

          .line strong { font-weight: 700; }
          .line em { font-style: italic; }
          .line del { text-decoration: line-through; }
          .line code {
            border: 1px solid #c6cec7;
            border-radius: 3px;
            padding: 0 2px;
            background: #f1f4f2;
            font-size: 0.92em;
          }

          .line a {
            color: #285f96;
            text-decoration: underline;
            text-underline-offset: 2px;
          }

          .note {
            margin-top: 10px;
            font-size: 0.95rem;
            color: var(--muted);
          }

          @media (max-width: 980px) {
            .wrap { grid-template-columns: 1fr; }
            .badge-frame { transform-origin: top center; transform: scale(0.95); }
          }
        </style>
      </head>
      <body>
        <div class="wrap">
          <section class="card">
            <h1>Compose Message</h1>
            <p>Author in the web app and preview how the fixed 320x240 viewport is typeset.</p>
            <textarea id="message-input" maxlength="#{MAX_CHARS}" placeholder="Write a Meshtastic-friendly message (max #{MAX_CHARS} chars)"></textarea>
            <div class="toolbar">
              <div class="meta" id="char-count">0 / #{MAX_CHARS}</div>
              <div class="controls">
                <button id="publish-btn" type="button">Publish</button>
              </div>
            </div>
            <div class="publish-status" id="publish-status"></div>
            <p class="note">Hard limits: 280 chars and a single 320x240 frame. Overflow is rejected (no next page).</p>
            <p class="note">Markdown: headings, quotes, lists, tasks, links, code, fences, rules, table lines, strikethrough. Typst-style control directives are non-printing: <code>#font(...)</code>, <code>#place(...)</code>, <code>#qr(...)</code>, <code>#event(...)</code>, <code>#contact(...)</code>.</p>
            <p class="note">Font is message-defined. Short IDs: <code>nsm</code>, <code>ns</code>, <code>ser</code>, <code>atk</code>, <code>ibm</code>. Example: <code>#font(&quot;nsm&quot;)</code>.</p>
            <p class="note">Placement accepts Typst-style locations. Default is right float. Example: <code>#place(bottom + right)[#qr(&quot;https://bbb.io/badge&quot;)]</code>.</p>
            <p class="note">More examples: <code>#qr(&quot;https://beagleboard.org&quot;)</code>, <code>#event(&quot;2026-03-01 18:30&quot;, &quot;Title&quot;, &quot;Location&quot;)</code>, <code>#contact(&quot;Name&quot;, &quot;+1-555-0100&quot;, &quot;name@example.com&quot;, &quot;https://example.com&quot;)</code>.</p>
          </section>

          <section class="card">
            <h1>320x240 Preview</h1>
            <p>Message viewport is fixed at 320x240. Trust stays in chrome metadata only.</p>
            <div class="preview-status" id="preview-status"></div>
            <div class="badge-frame" aria-label="badge-preview">
              <div class="chrome-top">
                <span id="trust-chip">UNVERIFIED</span>
                <span id="author-chip">Demo Peer</span>
                <span>now</span>
              </div>
              <div class="gutter-left" aria-hidden="true"></div>
              <div class="gutter-right" aria-hidden="true"></div>
              <div class="viewport" aria-hidden="true"></div>
              <div class="typst-render" id="typst-render" aria-hidden="true"></div>
              <div class="message-box" id="message-box">
                <div class="message-text" id="message-text"></div>
                <div class="message-artifacts" id="message-artifacts"></div>
              </div>
              <div class="chrome-bottom">
                <span>fixed 320x240</span>
              </div>
            </div>
          </section>
        </div>

        <script id="preview-config" type="application/json">#{config_json}</script>
        <script>
        #{PREVIEW_SCRIPT}
        </script>
      </body>
      </html>
      HTML
    end
  end
end
