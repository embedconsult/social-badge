require "json"
require "./models"

module SocialBadge
  class AuthoringPageService
    MAX_CHARS = Message::MAX_BODY_LENGTH

    def render(identity : Identity) : String
      author_name_json = identity.display_name.to_json
      trust_level_json = identity.trust_level.to_s.to_json

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
            width: min(1100px, 100% - 32px);
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
            min-height: 210px;
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

          .actions {
            display: flex;
            align-items: center;
            gap: 8px;
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
            font: 16px/18px "Menlo", "SFMono-Regular", "Consolas", monospace;
            color: #1f2520;
            user-select: text;
          }

          .line {
            height: 18px;
            white-space: pre;
          }

          .line strong { font-weight: 700; }
          .line em { font-style: italic; }
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
              <div class="actions">
                <button id="publish-btn" type="button">Publish</button>
              </div>
            </div>
            <div class="publish-status" id="publish-status"></div>
            <p class="note">Markdown subset: <code>**bold**</code>, <code>*italic*</code>, <code>`code`</code>, <code>[label](url)</code>, basic lists.</p>
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
          </section>
        </div>

        <script>
          (function () {
            const MAX_CHARS = #{MAX_CHARS};
            const CONTENT_WIDTH = 304;
            const MAX_LINES_PER_PAGE = 12;
            const FONT = "16px Menlo, SFMono-Regular, Consolas, monospace";
            const authorName = #{author_name_json};
            const trustLevel = #{trust_level_json};

            const input = document.getElementById('message-input');
            const charCount = document.getElementById('char-count');
            const publishStatus = document.getElementById('publish-status');
            const publishBtn = document.getElementById('publish-btn');
            const messageBox = document.getElementById('message-box');
            const pageChip = document.getElementById('page-chip');
            const prevPageBtn = document.getElementById('prev-page');
            const nextPageBtn = document.getElementById('next-page');
            const authorChip = document.getElementById('author-chip');
            const trustChip = document.getElementById('trust-chip');

            authorChip.textContent = authorName;
            trustChip.textContent = trustLevel;

            const measureCanvas = document.createElement('canvas');
            const measureCtx = measureCanvas.getContext('2d');
            measureCtx.font = FONT;

            let pages = [[]];
            let currentPage = 0;

            function normalize(text) {
              return text.replace(/\r\n?/g, '\n').split('\n').map(function (line) {
                return line.replace(/\\s+$/g, '');
              }).join('\n');
            }

            function measure(text) {
              return measureCtx.measureText(text).width;
            }

            function wrapLine(line) {
              if (line.length === 0) {
                return [''];
              }

              const words = line.split(/(\\s+)/).filter(function (part) { return part.length > 0; });
              const lines = [];
              let current = '';

              words.forEach(function (part) {
                const next = current + part;
                if (measure(next) <= CONTENT_WIDTH) {
                  current = next;
                  return;
                }

                if (current.length > 0) {
                  lines.push(current);
                  current = '';
                }

                if (measure(part) <= CONTENT_WIDTH) {
                  current = part.replace(/^\\s+/, '');
                  return;
                }

                let chunk = '';
                for (const char of part) {
                  const maybe = chunk + char;
                  if (measure(maybe) <= CONTENT_WIDTH) {
                    chunk = maybe;
                  } else {
                    if (chunk.length > 0) {
                      lines.push(chunk);
                    }
                    chunk = char;
                  }
                }
                current = chunk;
              });

              lines.push(current);
              return lines;
            }

            function inlineMarkdownToHtml(line) {
              const escaped = line
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');

              const linked = escaped.replace(/[([^]]+)](([^)]+))/g, function (_, label, url) {
                const safeUrl = url.replace(/"/g, '&quot;');
                return '<a href="' + safeUrl + '" target="_blank" rel="noreferrer noopener">' + label + '</a>';
              });

              return linked
                .replace(/`([^`]+)`/g, '<code>$1</code>')
                .replace(/**([^*]+)**/g, '<strong>$1</strong>')
                .replace(/*([^*]+)*/g, '<em>$1</em>');
            }

            function paginate(text) {
              const normalized = normalize(text);
              const wrapped = [];
              normalized.split('\n').forEach(function (rawLine) {
                wrapLine(rawLine).forEach(function (line) {
                  wrapped.push(line);
                });
              });

              if (wrapped.length === 0) {
                return [['']];
              }

              const result = [];
              for (let i = 0; i < wrapped.length; i += MAX_LINES_PER_PAGE) {
                result.push(wrapped.slice(i, i + MAX_LINES_PER_PAGE));
              }
              return result;
            }

            function renderPage() {
              const totalPages = pages.length;
              if (currentPage < 0) {
                currentPage = 0;
              }
              if (currentPage >= totalPages) {
                currentPage = totalPages - 1;
              }

              const pageLines = pages[currentPage] || [''];
              messageBox.innerHTML = pageLines.map(function (line) {
                return '<div class="line">' + inlineMarkdownToHtml(line) + '</div>';
              }).join('');

              pageChip.textContent = String(currentPage + 1) + '/' + String(totalPages);
              prevPageBtn.disabled = currentPage === 0;
              nextPageBtn.disabled = currentPage === totalPages - 1;
            }

            function updatePreview() {
              const value = input.value.slice(0, MAX_CHARS);
              if (value.length !== input.value.length) {
                input.value = value;
              }

              charCount.textContent = String(value.length) + ' / ' + String(MAX_CHARS);
              pages = paginate(value);
              currentPage = 0;
              renderPage();
            }

            async function publish() {
              const body = input.value.trim();
              if (!body) {
                publishStatus.textContent = 'Message is blank.';
                return;
              }

              publishBtn.disabled = true;
              publishStatus.textContent = 'Publishing...';

              try {
                const response = await fetch('/api/messages', {
                  method: 'POST',
                  headers: {'Content-Type': 'application/json'},
                  body: JSON.stringify({body: body})
                });

                if (!response.ok) {
                  const errorPayload = await response.json().catch(function () { return {error: 'Publish failed'}; });
                  publishStatus.textContent = errorPayload.error || 'Publish failed';
                  return;
                }

                publishStatus.textContent = 'Published.';
              } catch (error) {
                publishStatus.textContent = 'Network error while publishing.';
              } finally {
                publishBtn.disabled = false;
              }
            }

            input.addEventListener('input', updatePreview);
            prevPageBtn.addEventListener('click', function () {
              currentPage -= 1;
              renderPage();
            });
            nextPageBtn.addEventListener('click', function () {
              currentPage += 1;
              renderPage();
            });
            publishBtn.addEventListener('click', publish);

            updatePreview();
          })();
        </script>
      </body>
      </html>
      HTML
    end
  end
end
