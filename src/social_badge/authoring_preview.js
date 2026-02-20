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
  const BASE_CONTENT_WIDTH = 304;
  const PLACEMENT_DEFAULT = {profile: "right", alignX: "end", alignY: "start"};
  const PLACEMENT_NONE = {profile: "none", alignX: "start", alignY: "start"};
  const ARTIFACT_PLACEMENT_CLASSES = [
    "with-artifacts-right",
    "with-artifacts-left",
    "with-artifacts-top",
    "with-artifacts-bottom",
  ];
  const LAYOUT_PROFILES = {
    none: {placementClass: "", wrapWidth: BASE_CONTENT_WIDTH, maxLines: 12, maxArtifacts: 0},
    right: {placementClass: "with-artifacts-right", wrapWidth: 200, maxLines: 12, maxArtifacts: 2},
    left: {placementClass: "with-artifacts-left", wrapWidth: 200, maxLines: 12, maxArtifacts: 2},
    top: {placementClass: "with-artifacts-top", wrapWidth: BASE_CONTENT_WIDTH, maxLines: 6, maxArtifacts: 3},
    bottom: {placementClass: "with-artifacts-bottom", wrapWidth: BASE_CONTENT_WIDTH, maxLines: 6, maxArtifacts: 3},
  };
  const MAX_ARTIFACTS_TOTAL = 8;
  const FONT_SIZE = 16;

  const FONT_DIRECTIVE_RE = /#font\(\s*(?:"((?:[^"\\]|\\.)*)"|([A-Za-z0-9_-]+))\s*\)/g;
  const PLACE_BLOCK_RE = /#place\(\s*([^)]*?)\s*\)\s*\[([\s\S]*?)\]/g;
  const PLACE_DIRECTIVE_RE = /#place\(\s*([^)]*?)\s*\)/g;
  const QR_DIRECTIVE_RE = /#qr\(\s*"((?:[^"\\]|\\.)*)"\s*\)/g;
  const EVENT_DIRECTIVE_RE = /#event\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"(?:\s*,\s*"((?:[^"\\]|\\.)*)")?\s*\)/g;
  const CONTACT_DIRECTIVE_RE = /#contact\(\s*"((?:[^"\\]|\\.)*)"(?:\s*,\s*"((?:[^"\\]|\\.)*)")?(?:\s*,\s*"((?:[^"\\]|\\.)*)")?(?:\s*,\s*"((?:[^"\\]|\\.)*)")?\s*\)/g;

  const authorName = config.author_name || "Demo Peer";
  const trustLevel = config.trust_level || "UNVERIFIED";
  const fontProfiles = Array.isArray(config.font_profiles) ? config.font_profiles : [];
  const defaultFontId = config.default_font_id || (fontProfiles[0] && fontProfiles[0].id) || "noto-sans-mono";

  const input = document.getElementById("message-input");
  const charCount = document.getElementById("char-count");
  const publishStatus = document.getElementById("publish-status");
  const previewStatus = document.getElementById("preview-status");
  const publishBtn = document.getElementById("publish-btn");
  const typstRender = document.getElementById("typst-render");
  const messageBox = document.getElementById("message-box");
  const messageText = document.getElementById("message-text");
  const messageArtifacts = document.getElementById("message-artifacts");
  const authorChip = document.getElementById("author-chip");
  const trustChip = document.getElementById("trust-chip");

  if (!input || !charCount || !publishStatus || !previewStatus || !publishBtn || !typstRender || !messageBox || !messageText || !messageArtifacts || !authorChip || !trustChip) {
    return;
  }

  authorChip.textContent = authorName;
  trustChip.textContent = trustLevel;

  const measureCanvas = document.createElement("canvas");
  const measureCtx = measureCanvas.getContext("2d");

  let currentLayoutState = {overflowLines: 0, overflowArtifacts: 0, overflowChars: 0};
  let previewTimer = null;
  let previewRequestId = 0;
  let previewAbortController = null;

  function clonePlacement(placement) {
    return {
      profile: placement.profile,
      alignX: placement.alignX,
      alignY: placement.alignY,
    };
  }

  function escapeHtml(text) {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function compactLabel(text, maxLen) {
    if (text.length <= maxLen) return text;
    return text.slice(0, Math.max(0, maxLen - 1)) + "...";
  }

  function findFontProfile(profileId) {
    if (!profileId) return fontProfiles[0];
    const token = String(profileId).toLowerCase();
    return fontProfiles.find(function (profile) {
      return String(profile.id || "").toLowerCase() === token || String(profile.short_id || "").toLowerCase() === token;
    }) || fontProfiles[0];
  }

  function applyFontProfile(profileId) {
    const profile = findFontProfile(profileId);
    if (!profile) return;

    measureCtx.font = String(FONT_SIZE) + "px " + profile.css_stack;
    messageText.style.fontFamily = profile.css_stack;
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

    if (chunk.length > 0) chunks.push(chunk);
    return chunks;
  }

  function wrapWithPrefix(text, firstPrefix, continuationPrefix, wrapWidth) {
    const wrappedLines = [];
    const words = text.split(/(\s+)/).filter(function (part) {
      return part.length > 0;
    });

    let currentPrefix = firstPrefix;
    let current = firstPrefix;

    words.forEach(function (part) {
      const candidate = current + part;
      if (measure(candidate) <= wrapWidth) {
        current = candidate;
        return;
      }

      if (current.length > currentPrefix.length) {
        wrappedLines.push(current);
        currentPrefix = continuationPrefix;
        current = continuationPrefix;
      }

      if (measure(current + part) <= wrapWidth) {
        current += part.replace(/^\s+/, "");
        return;
      }

      const maxWidth = wrapWidth - measure(currentPrefix);
      const chunks = splitLongToken(part.replace(/^\s+/, ""), maxWidth);
      chunks.forEach(function (chunkText, index) {
        if (index === 0) {
          current += chunkText;
        } else {
          wrappedLines.push(current);
          currentPrefix = continuationPrefix;
          current = continuationPrefix + chunkText;
        }
      });
    });

    if (current.length > 0) wrappedLines.push(current);
    return wrappedLines.length > 0 ? wrappedLines : [""];
  }

  function parseTypstDateTime(value) {
    const match = value.match(/^(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}))?$/);
    if (!match) return null;
    return {datePart: match[1], timePart: match[2] || "09:00"};
  }

  function unescapeTypst(value) {
    return value
      .replace(/\\n/g, "\n")
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, "\\");
  }

  function parsePlaceExpression(raw) {
    let expr = String(raw || "").trim();
    if ((expr.startsWith('"') && expr.endsWith('"')) || (expr.startsWith("'") && expr.endsWith("'"))) {
      expr = expr.slice(1, -1);
    }

    const tokens = expr
      .toLowerCase()
      .replace(/\s+/g, "")
      .split("+")
      .filter(function (token) {
        return token.length > 0;
      });

    const has = function (token) {
      return tokens.indexOf(token) >= 0;
    };

    if (has("none") || has("off") || has("hidden")) return clonePlacement(PLACEMENT_NONE);

    let profile = PLACEMENT_DEFAULT.profile;
    if (has("left")) {
      profile = "left";
    } else if (has("right")) {
      profile = "right";
    } else if (has("top")) {
      profile = "top";
    } else if (has("bottom")) {
      profile = "bottom";
    }

    let alignX = has("right") ? "end" : has("center") ? "center" : "start";
    let alignY = has("bottom") ? "end" : has("center") ? "center" : "start";

    if (profile === "left") alignX = "start";
    if (profile === "right") alignX = "end";

    return {profile: profile, alignX: alignX, alignY: alignY};
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

    if (location && location.length > 0) lines.push("LOCATION:" + location);
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

  function cleanUrl(raw) {
    return raw.replace(/[.,!?;:)\]]+$/g, "");
  }

  function pushArtifact(state, kind, title, payload, placement) {
    if (!payload || payload.length === 0) return;
    if (state.artifacts.length >= MAX_ARTIFACTS_TOTAL) return;

    const key = payload;
    if (state.seen.has(key)) return;
    state.seen.add(key);

    state.artifacts.push({
      kind: kind,
      title: title,
      payload: payload,
      placement: clonePlacement(placement),
    });
  }

  function collectControlArtifacts(text, placement, state) {
    let working = text;

    working = working.replace(QR_DIRECTIVE_RE, function (_, rawUrl) {
      const url = cleanUrl(unescapeTypst(rawUrl));
      pushArtifact(state, "qr", compactLabel(url, 28), url, placement);
      return "";
    });

    working = working.replace(EVENT_DIRECTIVE_RE, function (_, rawDateTime, rawTitle, rawLocation) {
      const dateTime = unescapeTypst(rawDateTime);
      const title = unescapeTypst(rawTitle);
      const location = rawLocation ? unescapeTypst(rawLocation) : "";
      const parsed = parseTypstDateTime(dateTime);
      const datePart = parsed ? parsed.datePart : "1970-01-01";
      const timePart = parsed ? parsed.timePart : "09:00";
      const payload = buildEventPayload(datePart, timePart, title, location);
      pushArtifact(state, "event", compactLabel(title, 28), payload, placement);
      return "";
    });

    working = working.replace(CONTACT_DIRECTIVE_RE, function (_, rawName, rawPhone, rawEmail, rawUrl) {
      const name = unescapeTypst(rawName);
      const phone = rawPhone ? unescapeTypst(rawPhone) : "";
      const email = rawEmail ? unescapeTypst(rawEmail) : "";
      const url = rawUrl ? unescapeTypst(rawUrl) : "";
      const payload = buildContactPayload(name, phone, email, url);
      pushArtifact(state, "contact", compactLabel(name, 28), payload, placement);
      return "";
    });

    return working;
  }

  function collectUrlsFromText(text, placement, state) {
    if (placement.profile === "none") return;

    const mdLinkRegex = /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
    const rawUrlRegex = /https?:\/\/[^\s<>()"'`]+/g;

    mdLinkRegex.lastIndex = 0;
    rawUrlRegex.lastIndex = 0;

    let mdMatch;
    while ((mdMatch = mdLinkRegex.exec(text)) !== null) {
      const url = cleanUrl(mdMatch[2]);
      pushArtifact(state, "url", compactLabel(mdMatch[1], 28), url, placement);
    }

    let rawMatch;
    while ((rawMatch = rawUrlRegex.exec(text)) !== null) {
      const url = cleanUrl(rawMatch[0]);
      pushArtifact(state, "url", compactLabel(url, 28), url, placement);
    }
  }

  function cleanupRenderableText(text) {
    return text
      .split("\n")
      .map(function (line) {
        return line.replace(/\s+$/g, "");
      })
      .join("\n")
      .replace(/\n{3,}/g, "\n\n")
      .replace(/^\n+/, "")
      .replace(/\n+$/, "");
  }

  function parseMessageModel(normalizedText) {
    let working = normalizedText;
    let fontToken = defaultFontId;
    let placement = clonePlacement(PLACEMENT_DEFAULT);
    const state = {artifacts: [], seen: new Set()};

    working = working.replace(FONT_DIRECTIVE_RE, function (_, quotedToken, bareToken) {
      const token = quotedToken ? unescapeTypst(quotedToken) : (bareToken || "");
      if (token.length > 0) fontToken = token;
      return "";
    });

    working = working.replace(PLACE_BLOCK_RE, function (_, rawPlace, body) {
      const blockPlacement = parsePlaceExpression(rawPlace);
      placement = blockPlacement;
      collectControlArtifacts(body, blockPlacement, state);
      return "";
    });

    working = working.replace(PLACE_DIRECTIVE_RE, function (_, rawPlace) {
      placement = parsePlaceExpression(rawPlace);
      return "";
    });

    working = collectControlArtifacts(working, placement, state);
    collectUrlsFromText(working, placement, state);

    return {
      fontToken: fontToken,
      placement: placement,
      artifacts: state.artifacts,
      visibleText: cleanupRenderableText(working),
    };
  }

  function parseBlocks(normalizedText) {
    const lines = normalizedText.length > 0 ? normalizedText.split("\n") : [""];
    const blocks = [];
    let inCodeFence = false;

    lines.forEach(function (rawLine) {
      if (/^```/.test(rawLine)) {
        inCodeFence = !inCodeFence;
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
        blocks.push({className: "hr", text: "------------------------------", inline: false, firstPrefix: "", continuationPrefix: ""});
        return;
      }

      const quoteMatch = rawLine.match(/^\s*>\s?(.*)$/);
      if (quoteMatch) {
        blocks.push({className: "quote", text: quoteMatch[1], inline: true, firstPrefix: "| ", continuationPrefix: "| "});
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
        blocks.push({className: "list", text: listMatch[1], inline: true, firstPrefix: "* ", continuationPrefix: "  "});
        return;
      }

      if (/^\s*\|.*\|\s*$/.test(rawLine)) {
        const cells = rawLine.split("|").slice(1, -1).map(function (cell) {
          return cell.trim();
        }).filter(function (cell) {
          return cell.length > 0;
        });
        blocks.push({className: "table", text: cells.join(" | "), inline: true, firstPrefix: "", continuationPrefix: "  "});
        return;
      }

      blocks.push({className: "paragraph", text: rawLine, inline: true, firstPrefix: "", continuationPrefix: "  "});
    });

    return blocks;
  }

  function blocksToLines(blocks, wrapWidth) {
    const lines = [];
    blocks.forEach(function (block) {
      if (block.className === "blank") {
        lines.push({className: "blank", text: "", inline: false});
        return;
      }

      const wrapped = wrapWithPrefix(block.text, block.firstPrefix || "", block.continuationPrefix || "", wrapWidth);
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

  function shapeLines(normalized, wrapWidth) {
    const blocks = parseBlocks(normalized);
    const lines = blocksToLines(blocks, wrapWidth);
    return lines.length > 0 ? lines : [{className: "blank", text: "", inline: false}];
  }

  function renderLine(lineData) {
    if (!lineData.inline) return escapeHtml(lineData.text);
    return inlineMarkdownToHtml(lineData.text);
  }

  function renderInlineArtifacts() {
    messageBox.classList.remove("with-artifacts");
    ARTIFACT_PLACEMENT_CLASSES.forEach(function (className) {
      messageBox.classList.remove(className);
    });

    messageBox.style.alignContent = "start";
    messageArtifacts.innerHTML = "";
  }

  function renderLayout(lines, artifacts, placement) {
    messageText.innerHTML = lines.map(function (lineData) {
      const className = lineData.className ? " " + lineData.className : "";
      return '<div class="line' + className + '">' + renderLine(lineData) + "</div>";
    }).join("");

    renderInlineArtifacts(artifacts, placement);
  }

  async function renderTypstPreview(messageBody) {
    const requestId = ++previewRequestId;
    if (previewAbortController) previewAbortController.abort();
    previewAbortController = new AbortController();

    if (!messageBody.trim()) {
      typstRender.innerHTML = "";
      previewStatus.textContent = "";
      return;
    }

    try {
      const response = await fetch("/api/preview/render", {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({body: messageBody}),
        signal: previewAbortController.signal,
      });

      if (!response.ok) {
        const errorPayload = await response.json().catch(function () {
          return {error: "Preview render failed"};
        });
        if (requestId === previewRequestId) {
          typstRender.innerHTML = "";
          previewStatus.textContent = errorPayload.error || "Preview render failed";
        }
        return;
      }

      const payload = await response.json().catch(function () {
        return {svg: ""};
      });

      if (requestId === previewRequestId) {
        const svg = typeof payload.svg === "string" ? payload.svg : "";
        typstRender.innerHTML = svg;
        previewStatus.textContent = "";
      }
    } catch (error) {
      if (error && error.name === "AbortError") return;
      if (requestId === previewRequestId) {
        typstRender.innerHTML = "";
        previewStatus.textContent = "Preview render failed";
      }
    } finally {
      if (requestId === previewRequestId) previewAbortController = null;
    }
  }

  function scheduleTypstPreview(messageBody) {
    if (previewTimer) clearTimeout(previewTimer);
    previewTimer = setTimeout(function () {
      renderTypstPreview(messageBody);
    }, 240);
  }

  function updatePreview() {
    const rawValue = input.value;
    const value = rawValue.slice(0, MAX_CHARS);
    if (value.length !== rawValue.length) input.value = value;

    const normalized = normalize(value);
    const model = parseMessageModel(normalized);
    applyFontProfile(model.fontToken);

    const placementProfile = model.placement.profile;
    const inlineArtifactsEnabled = model.artifacts.length > 0 && placementProfile !== "none";
    const activeLayout = inlineArtifactsEnabled
      ? (LAYOUT_PROFILES[placementProfile] || LAYOUT_PROFILES[PLACEMENT_DEFAULT.profile])
      : LAYOUT_PROFILES.none;

    const lines = shapeLines(model.visibleText, activeLayout.wrapWidth);
    const visibleLines = lines.slice(0, activeLayout.maxLines);
    const overflowLines = Math.max(0, lines.length - activeLayout.maxLines);
    const overflowArtifacts = inlineArtifactsEnabled ? Math.max(0, model.artifacts.length - activeLayout.maxArtifacts) : 0;
    const overflowChars = Math.max(0, rawValue.length - value.length);
    const overflow = overflowLines > 0 || overflowArtifacts > 0;

    charCount.textContent = String(value.length) + " / " + String(MAX_CHARS);
    renderLayout(visibleLines, [], PLACEMENT_NONE);
    scheduleTypstPreview(value);

    currentLayoutState = {
      overflowLines: overflowLines,
      overflowArtifacts: overflowArtifacts,
      overflowChars: overflowChars,
    };

    const isBlank = value.trim().length === 0;
    if (overflow) {
      const parts = [];
      if (overflowLines > 0) parts.push("+" + String(overflowLines) + " lines");
      if (overflowArtifacts > 0) parts.push("+" + String(overflowArtifacts) + " artifacts");
      publishStatus.textContent = "Does not fit fixed 320x240: " + parts.join(", ") + ".";
    } else if (overflowChars > 0) {
      publishStatus.textContent = "Trimmed to " + String(MAX_CHARS) + " characters.";
    } else {
      publishStatus.textContent = "";
    }

    publishBtn.disabled = isBlank || overflow;
  }

  async function publish() {
    const body = input.value.trim();
    if (!body) {
      publishStatus.textContent = "Message is blank.";
      return;
    }
    if (currentLayoutState.overflowLines > 0 || currentLayoutState.overflowArtifacts > 0 || currentLayoutState.overflowChars > 0) {
      publishStatus.textContent = "Message must fit fixed 320x240 before publish.";
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
  publishBtn.addEventListener("click", publish);
  updatePreview();
})();
