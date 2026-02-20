(function () {
  const configNode = document.getElementById("preview-config");
  if (!configNode) return;

  let config;
  try {
    config = JSON.parse(configNode.textContent || "{}");
  } catch (_) {
    return;
  }

  const MAX_CHARS = config.max_chars || 280;
  const CONTENT_WIDTH = 304;
  const MAX_LINES_PER_PAGE = 12;
  const FONT_SIZE = 16;
  const authorName = config.author_name || "Demo Peer";
  const trustLevel = config.trust_level || "UNVERIFIED";
  const fontProfiles = Array.isArray(config.font_profiles) ? config.font_profiles : [];
  const defaultFontId = config.default_font_id || (fontProfiles[0] && fontProfiles[0].id);

  const input = document.getElementById("message-input");
  const charCount = document.getElementById("char-count");
  const publishStatus = document.getElementById("publish-status");
  const publishBtn = document.getElementById("publish-btn");
  const messageBox = document.getElementById("message-box");
  const pageChip = document.getElementById("page-chip");
  const prevPageBtn = document.getElementById("prev-page");
  const nextPageBtn = document.getElementById("next-page");
  const authorChip = document.getElementById("author-chip");
  const trustChip = document.getElementById("trust-chip");
  const fontSelect = document.getElementById("font-profile");
  const artifactList = document.getElementById("artifact-list");

  if (!input || !charCount || !publishStatus || !publishBtn || !messageBox || !pageChip || !prevPageBtn || !nextPageBtn || !authorChip || !trustChip || !fontSelect || !artifactList) {
    return;
  }

  authorChip.textContent = authorName;
  trustChip.textContent = trustLevel;

  const measureCanvas = document.createElement("canvas");
  const measureCtx = measureCanvas.getContext("2d");

  let pages = [[]];
  let currentPage = 0;

  function escapeHtml(text) {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function findFontProfile(profileId) {
    return fontProfiles.find(function (profile) {
      return profile.id === profileId;
    }) || fontProfiles[0];
  }

  function applyFontProfile(profileId) {
    const profile = findFontProfile(profileId);
    if (!profile) return;

    fontSelect.value = profile.id;
    measureCtx.font = String(FONT_SIZE) + "px " + profile.css_stack;
    messageBox.style.fontFamily = profile.css_stack;
    document.documentElement.style.setProperty("--preview-font-family", profile.css_stack);
  }

  function normalize(text) {
    return text
      .replace(/\r\n?/g, "\n")
      .split("\n")
      .map(function (line) {
        return line.replace(/\s+$/g, "");
      })
      .join("\n");
  }

  function measure(text) {
    return measureCtx.measureText(text).width;
  }

  function splitLongToken(token, maxWidth) {
    const chunks = [];
    let chunk = "";

    for (const char of token) {
      const candidate = chunk + char;
      if (measure(candidate) <= maxWidth || chunk.length === 0) {
        chunk = candidate;
      } else {
        chunks.push(chunk);
        chunk = char;
      }
    }

    if (chunk.length > 0) {
      chunks.push(chunk);
    }

    return chunks;
  }

  function wrapWithPrefix(text, firstPrefix, continuationPrefix) {
    const wrappedLines = [];
    const words = text.split(/(\s+)/).filter(function (part) {
      return part.length > 0;
    });

    let currentPrefix = firstPrefix;
    let current = firstPrefix;

    words.forEach(function (part) {
      const candidate = current + part;
      if (measure(candidate) <= CONTENT_WIDTH) {
        current = candidate;
        return;
      }

      if (current.length > currentPrefix.length) {
        wrappedLines.push(current);
        currentPrefix = continuationPrefix;
        current = continuationPrefix;
      }

      if (measure(current + part) <= CONTENT_WIDTH) {
        current += part.replace(/^\s+/, "");
        return;
      }

      const maxWidth = CONTENT_WIDTH - measure(currentPrefix);
      const chunks = splitLongToken(part.replace(/^\s+/, ""), maxWidth);
      chunks.forEach(function (chunk, index) {
        if (index === 0) {
          current += chunk;
        } else {
          wrappedLines.push(current);
          currentPrefix = continuationPrefix;
          current = continuationPrefix + chunk;
        }
      });
    });

    if (current.length > 0) {
      wrappedLines.push(current);
    }

    return wrappedLines.length > 0 ? wrappedLines : [""];
  }

  function parseBlocks(normalizedText) {
    const lines = normalizedText.split("\n");
    const blocks = [];
    let inCodeFence = false;

    lines.forEach(function (rawLine) {
      if (/^```/.test(rawLine)) {
        inCodeFence = !inCodeFence;
        return;
      }

      const eventMatch = rawLine.match(/^@event\s+(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}))?\s*\|\s*([^|]+?)(?:\s*\|\s*(.+))?$/);
      if (eventMatch) {
        const label = "EVENT " + eventMatch[1] + " " + (eventMatch[2] || "09:00") + " " + eventMatch[3].trim();
        const withLocation = eventMatch[4] ? label + " @ " + eventMatch[4].trim() : label;
        blocks.push({className: "table", text: withLocation, inline: true, firstPrefix: "", continuationPrefix: "  "});
        return;
      }

      const contactMatch = rawLine.match(/^@contact\s+([^|]+?)(?:\s*\|\s*([^|]*))?(?:\s*\|\s*([^|]*))?(?:\s*\|\s*(\S+))?$/);
      if (contactMatch) {
        const segments = [contactMatch[1].trim()];
        if (contactMatch[2] && contactMatch[2].trim().length > 0) segments.push(contactMatch[2].trim());
        if (contactMatch[3] && contactMatch[3].trim().length > 0) segments.push(contactMatch[3].trim());
        blocks.push({className: "table", text: "CONTACT " + segments.join(" | "), inline: true, firstPrefix: "", continuationPrefix: "  "});
        return;
      }

      if (inCodeFence) {
        blocks.push({className: "code", text: rawLine, inline: false, firstPrefix: "", continuationPrefix: ""});
        return;
      }

      if (/^\s*$/.test(rawLine)) {
        blocks.push({className: "blank", text: "", inline: false, firstPrefix: "", continuationPrefix: ""});
        return;
      }

      const headingMatch = rawLine.match(/^([#]{1,6})\s+(.*)$/);
      if (headingMatch) {
        const level = Math.min(3, headingMatch[1].length);
        blocks.push({className: "heading-" + String(level), text: headingMatch[2], inline: true, firstPrefix: "", continuationPrefix: "  "});
        return;
      }

      if (/^(\*\*\*+|---+|___+)\s*$/.test(rawLine)) {
        blocks.push({className: "hr", text: "──────────────────────────────", inline: false, firstPrefix: "", continuationPrefix: ""});
        return;
      }

      const quoteMatch = rawLine.match(/^\s*>\s?(.*)$/);
      if (quoteMatch) {
        blocks.push({className: "quote", text: quoteMatch[1], inline: true, firstPrefix: "│ ", continuationPrefix: "│ "});
        return;
      }

      const taskMatch = rawLine.match(/^\s*[-*+]\s+\[( |x|X)\]\s+(.*)$/);
      if (taskMatch) {
        const checked = taskMatch[1].toLowerCase() === "x";
        blocks.push({className: "list", text: taskMatch[2], inline: true, firstPrefix: checked ? "[x] " : "[ ] ", continuationPrefix: "    "});
        return;
      }

      const orderedMatch = rawLine.match(/^\s*(\d+)\.\s+(.*)$/);
      if (orderedMatch) {
        blocks.push({className: "list", text: orderedMatch[2], inline: true, firstPrefix: orderedMatch[1] + ". ", continuationPrefix: "   "});
        return;
      }

      const listMatch = rawLine.match(/^\s*[-*+]\s+(.*)$/);
      if (listMatch) {
        blocks.push({className: "list", text: listMatch[1], inline: true, firstPrefix: "• ", continuationPrefix: "  "});
        return;
      }

      if (/^\s*\|.*\|\s*$/.test(rawLine)) {
        const cells = rawLine
          .split("|")
          .slice(1, -1)
          .map(function (cell) {
            return cell.trim();
          })
          .filter(function (cell) {
            return cell.length > 0;
          });

        blocks.push({className: "table", text: cells.join(" | "), inline: true, firstPrefix: "", continuationPrefix: "  "});
        return;
      }

      blocks.push({className: "paragraph", text: rawLine, inline: true, firstPrefix: "", continuationPrefix: "  "});
    });

    return blocks;
  }

  function blocksToLines(blocks) {
    const lines = [];

    blocks.forEach(function (block) {
      if (block.className === "blank") {
        lines.push({className: "blank", text: "", inline: false});
        return;
      }

      const wrapped = wrapWithPrefix(block.text, block.firstPrefix || "", block.continuationPrefix || "");
      wrapped.forEach(function (lineText) {
        lines.push({className: block.className, text: lineText, inline: block.inline});
      });
    });

    return lines.length > 0 ? lines : [{className: "blank", text: "", inline: false}];
  }

  function inlineMarkdownToHtml(line) {
    const escaped = escapeHtml(line);

    const withLinks = escaped
      .replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g, function (_, label, url) {
        return '<a href="' + url + '" target="_blank" rel="noreferrer noopener">' + label + "</a>";
      })
      .replace(/\b(https?:\/\/[^\s<]+)\b/g, function (_, url) {
        return '<a href="' + url + '" target="_blank" rel="noreferrer noopener">' + url + "</a>";
      });

    return withLinks
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/~~([^~]+)~~/g, "<del>$1</del>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/\*([^*]+)\*/g, "<em>$1</em>");
  }

  function paginate(text) {
    const normalized = normalize(text);
    const blocks = parseBlocks(normalized);
    const lines = blocksToLines(blocks);
    const pagesOut = [];

    for (let i = 0; i < lines.length; i += MAX_LINES_PER_PAGE) {
      pagesOut.push(lines.slice(i, i + MAX_LINES_PER_PAGE));
    }

    return pagesOut.length > 0 ? pagesOut : [[{className: "blank", text: "", inline: false}]];
  }

  function renderLine(lineData) {
    if (!lineData.inline) {
      return escapeHtml(lineData.text);
    }
    return inlineMarkdownToHtml(lineData.text);
  }

  function renderPage() {
    const totalPages = pages.length;
    if (currentPage < 0) currentPage = 0;
    if (currentPage >= totalPages) currentPage = totalPages - 1;

    const pageLines = pages[currentPage] || [{className: "blank", text: "", inline: false}];
    messageBox.innerHTML = pageLines
      .map(function (lineData) {
        const className = lineData.className ? " " + lineData.className : "";
        return '<div class="line' + className + '">' + renderLine(lineData) + "</div>";
      })
      .join("");

    pageChip.textContent = String(currentPage + 1) + "/" + String(totalPages);
    prevPageBtn.disabled = currentPage === 0;
    nextPageBtn.disabled = currentPage === totalPages - 1;
  }

  function toQrUrl(payload) {
    return "https://api.qrserver.com/v1/create-qr-code/?size=96x96&ecc=M&data=" + encodeURIComponent(payload);
  }

  function buildEventPayload(datePart, timePart, title, location) {
    const compactDate = datePart.replace(/-/g, "");
    const compactTime = (timePart || "09:00").replace(":", "") + "00";
    const lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "BEGIN:VEVENT",
      "DTSTART:" + compactDate + "T" + compactTime,
      "SUMMARY:" + title,
    ];

    if (location && location.length > 0) {
      lines.push("LOCATION:" + location);
    }

    lines.push("END:VEVENT");
    lines.push("END:VCALENDAR");
    return lines.join("\n");
  }

  function buildContactPayload(name, phone, email, url) {
    const lines = ["BEGIN:VCARD", "VERSION:3.0", "FN:" + name];
    if (phone && phone.length > 0) lines.push("TEL:" + phone);
    if (email && email.length > 0) lines.push("EMAIL:" + email);
    if (url && url.length > 0) lines.push("URL:" + url);
    lines.push("END:VCARD");
    return lines.join("\n");
  }

  function detectArtifacts(normalized) {
    const artifacts = [];
    const seen = new Set();

    function push(kind, title, payload) {
      const key = kind + "::" + payload;
      if (seen.has(key)) return;
      seen.add(key);
      artifacts.push({kind: kind, title: title, payload: payload});
    }

    const mdLinkRegex = /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
    let mdMatch;
    while ((mdMatch = mdLinkRegex.exec(normalized)) !== null) {
      push("url", mdMatch[1], mdMatch[2]);
    }

    const rawUrlRegex = /\bhttps?:\/\/[^\s<>()]+/g;
    let rawMatch;
    while ((rawMatch = rawUrlRegex.exec(normalized)) !== null) {
      push("url", rawMatch[0], rawMatch[0]);
    }

    normalized.split("\n").forEach(function (line) {
      const eventMatch = line.match(/^@event\s+(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}))?\s*\|\s*([^|]+?)(?:\s*\|\s*(.+))?$/);
      if (eventMatch) {
        const datePart = eventMatch[1];
        const timePart = eventMatch[2] || "09:00";
        const title = eventMatch[3].trim();
        const location = eventMatch[4] ? eventMatch[4].trim() : "";
        const payload = buildEventPayload(datePart, timePart, title, location);
        push("event", title + " (" + datePart + " " + timePart + ")", payload);
      }

      const contactMatch = line.match(/^@contact\s+([^|]+?)(?:\s*\|\s*([^|]*))?(?:\s*\|\s*([^|]*))?(?:\s*\|\s*(\S+))?$/);
      if (contactMatch) {
        const name = contactMatch[1].trim();
        const phone = contactMatch[2] ? contactMatch[2].trim() : "";
        const email = contactMatch[3] ? contactMatch[3].trim() : "";
        const url = contactMatch[4] ? contactMatch[4].trim() : "";
        const payload = buildContactPayload(name, phone, email, url);
        push("contact", name, payload);
      }
    });

    return artifacts.slice(0, 8);
  }

  function renderArtifacts(artifacts) {
    if (artifacts.length === 0) {
      artifactList.innerHTML = '<p class="artifact-empty">No URL, @event, or @contact artifacts detected.</p>';
      return;
    }

    artifactList.innerHTML = artifacts
      .map(function (artifact) {
        const label = escapeHtml(artifact.title);
        const kind = escapeHtml(artifact.kind);
        const qrUrl = toQrUrl(artifact.payload);
        return (
          '<article class="artifact-card">' +
          '<div class="artifact-kind">' + kind + "</div>" +
          '<div class="artifact-title">' + label + "</div>" +
          '<img class="artifact-code" alt="QR for ' + label + '" src="' + qrUrl + '">' +
          "</article>"
        );
      })
      .join("");
  }

  function updatePreview() {
    const value = input.value.slice(0, MAX_CHARS);
    if (value.length !== input.value.length) {
      input.value = value;
    }

    const normalized = normalize(value);
    charCount.textContent = String(value.length) + " / " + String(MAX_CHARS);
    pages = paginate(value);
    currentPage = 0;
    renderPage();
    renderArtifacts(detectArtifacts(normalized));
  }

  async function publish() {
    const body = input.value.trim();
    if (!body) {
      publishStatus.textContent = "Message is blank.";
      return;
    }

    publishBtn.disabled = true;
    publishStatus.textContent = "Publishing...";

    try {
      const response = await fetch("/api/messages", {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({body: body}),
      });

      if (!response.ok) {
        const errorPayload = await response.json().catch(function () {
          return {error: "Publish failed"};
        });
        publishStatus.textContent = errorPayload.error || "Publish failed";
        return;
      }

      publishStatus.textContent = "Published.";
    } catch (_) {
      publishStatus.textContent = "Network error while publishing.";
    } finally {
      publishBtn.disabled = false;
    }
  }

  input.addEventListener("input", updatePreview);
  prevPageBtn.addEventListener("click", function () {
    currentPage -= 1;
    renderPage();
  });
  nextPageBtn.addEventListener("click", function () {
    currentPage += 1;
    renderPage();
  });
  fontSelect.addEventListener("change", function () {
    applyFontProfile(fontSelect.value);
    updatePreview();
  });
  publishBtn.addEventListener("click", publish);

  applyFontProfile(defaultFontId);
  updatePreview();
})();
