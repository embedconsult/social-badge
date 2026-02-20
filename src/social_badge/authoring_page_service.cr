require "html"
require "json"
require "./models"

module SocialBadge
  class AuthoringPageService
    MAX_CHARS      = Message::MAX_BODY_LENGTH
    PREVIEW_SCRIPT = {{ read_file("#{__DIR__}/authoring_preview.js") }}

    FONT_PROFILES = [
      {
        id:        "noto-sans-mono",
        label:     "Noto Sans Mono",
        css_stack: "\"Noto Sans Mono\", \"Liberation Mono\", \"DejaVu Sans Mono\", monospace",
      },
      {
        id:        "noto-sans",
        label:     "Noto Sans",
        css_stack: "\"Noto Sans\", \"Liberation Sans\", \"DejaVu Sans\", sans-serif",
      },
      {
        id:        "noto-serif",
        label:     "Noto Serif",
        css_stack: "\"Noto Serif\", \"Liberation Serif\", \"DejaVu Serif\", serif",
      },
      {
        id:        "atkinson",
        label:     "Atkinson Hyperlegible",
        css_stack: "\"Atkinson Hyperlegible\", \"Noto Sans\", \"Liberation Sans\", sans-serif",
      },
      {
        id:        "ibm-plex-mono",
        label:     "IBM Plex Mono",
        css_stack: "\"IBM Plex Mono\", \"Noto Sans Mono\", \"Liberation Mono\", monospace",
      },
    ] of NamedTuple(id: String, label: String, css_stack: String)

    def render(identity : Identity) : String
      font_options_html = build_font_options
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

          h2 {
            margin: 0;
            font-size: 1.06rem;
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
            overflow: hidden;
            font-size: 16px;
            line-height: 18px;
            font-family: var(--preview-font-family);
            color: #1f2520;
            user-select: text;
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

          .artifact-panel {
            margin-top: 14px;
            border-top: 1px solid var(--edge);
            padding-top: 12px;
          }

          .artifact-panel p {
            margin-top: 6px;
            margin-bottom: 10px;
          }

          .artifact-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 10px;
          }

          .artifact-card {
            border: 1px solid var(--edge);
            border-radius: 8px;
            background: #f9fbf9;
            padding: 8px;
            display: grid;
            gap: 8px;
          }

          .artifact-kind {
            font: 11px/1 "Menlo", "SFMono-Regular", "Consolas", monospace;
            letter-spacing: 0.03em;
            color: #456657;
            text-transform: uppercase;
          }

          .artifact-title {
            font-weight: 700;
            font-size: 0.92rem;
            line-height: 1.2;
            color: #1f2520;
          }

          .artifact-code {
            width: 96px;
            height: 96px;
            border: 1px solid var(--edge);
            background: #fff;
          }

          .artifact-empty {
            color: var(--muted);
            font-size: 0.92rem;
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
                <label for="font-profile">Font</label>
                <select id="font-profile">#{font_options_html}</select>
                <button id="publish-btn" type="button">Publish</button>
              </div>
            </div>
            <div class="publish-status" id="publish-status"></div>
            <p class="note">Markdown: headings, quotes, lists, tasks, links, code, fences, rules, table lines, strikethrough. QR artifacts: URLs, <code>@event</code>, <code>@contact</code>.</p>
            <p class="note">Event syntax: <code>@event 2026-03-01 18:30 | Title | Location</code>. Contact syntax: <code>@contact Name | phone | email | https://url</code>.</p>
          </section>

          <section class="card">
            <h1>320x240 Preview</h1>
            <p>Top/bottom bars are chrome. Trust is shown in chrome only.</p>
            <div class="badge-frame" aria-label="badge-preview">
              <div class="chrome-top">
                <span id="trust-chip">UNVERIFIED</span>
                <span id="author-chip">Demo Peer</span>
                <span>now</span>
              </div>
              <div class="gutter-left" aria-hidden="true"></div>
              <div class="gutter-right" aria-hidden="true"></div>
              <div class="viewport" aria-hidden="true"></div>
              <div class="message-box" id="message-box"></div>
              <div class="chrome-bottom">
                <button class="secondary" id="prev-page" type="button">Prev</button>
                <span id="page-chip">1/1</span>
                <button class="secondary" id="next-page" type="button">Next</button>
              </div>
            </div>

            <section class="artifact-panel">
              <h2>QR Artifacts</h2>
              <p>Generated from URLs, calendar entries, and contact cards.</p>
              <div class="artifact-list" id="artifact-list"></div>
            </section>
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

    private def build_font_options : String
      FONT_PROFILES.map do |profile|
        id = HTML.escape(profile[:id])
        label = HTML.escape(profile[:label])
        %(<option value="#{id}">#{label}</option>)
      end.join
    end
  end
end
