require "digest/sha256"
require "file_utils"
require "json"
require "path"

module SocialBadge
  class TypstPreviewService
    ROOT_DIR              = File.expand_path("../..", __DIR__)
    CACHE_DIR             = File.join(ROOT_DIR, "tmp/typst-preview")
    RENDER_FN             = "render-message-window"
    RENDER_SPEC_VERSION   = "msg_320x240_v1"
    INVALID_PAYLOAD_ERROR = "Invalid preview payload"

    class UnavailableError < Exception
    end

    class RenderError < Exception
    end

    struct PreviewRequest
      include JSON::Serializable

      getter body : String
    end

    struct PreviewResponse
      include JSON::Serializable

      getter svg : String
      getter cache_key : String
      getter render_spec_version : String

      def initialize(@svg : String, @cache_key : String, @render_spec_version : String = RENDER_SPEC_VERSION)
      end
    end

    def render(request_body : IO?) : PreviewResponse
      payload = parse_payload(request_body)
      validate_body(payload.body)
      raise UnavailableError.new("Typst preview unavailable: typst not found") unless typst_available?

      model = parse_message(payload.body)
      typ_source = build_typst_source(model[:font_id], model[:body_typst])
      cache_key = Digest::SHA256.hexdigest(typ_source)

      svg = compile_or_load_svg(cache_key, typ_source)
      PreviewResponse.new(svg: svg, cache_key: cache_key)
    end

    private def parse_payload(request_body : IO?) : PreviewRequest
      raw_payload = request_body.try(&.gets_to_end) || "{}"
      PreviewRequest.from_json(raw_payload)
    rescue JSON::ParseException | JSON::SerializableError
      raise ArgumentError.new(INVALID_PAYLOAD_ERROR)
    end

    private def validate_body(body : String)
      raise ArgumentError.new("Message body exceeds #{Message::MAX_BODY_LENGTH} characters") if body.size > Message::MAX_BODY_LENGTH
    end

    private def parse_message(body : String) : NamedTuple(font_id: String, body_typst: String)
      lines = normalize_lines(body)
      nodes = [] of String
      font_id = "nsm"
      current_place = "right"

      lines.each do |line|
        stripped = line.strip

        if match = stripped.match(/^#font\(\s*(?:"([A-Za-z0-9_-]+)"|([A-Za-z0-9_-]+))\s*\)$/)
          font_token = match[1]? || match[2]? || ""
          font_id = normalize_font(font_token)
          next
        end

        if match = stripped.match(/^#place\(\s*([^\)]*?)\s*\)\s*\[\s*#qr\(\s*"((?:[^"\\]|\\.)*)"\s*\)\s*\]\s*$/)
          current_place = normalize_place(match[1])
          url = unescape_typst(match[2])
          nodes << qr_node(current_place, url)
          next
        end

        if match = stripped.match(/^#place\(\s*([^\)]*?)\s*\)$/)
          current_place = normalize_place(match[1])
          next
        end

        if match = stripped.match(/^#qr\(\s*"((?:[^"\\]|\\.)*)"\s*\)$/)
          nodes << qr_node(current_place, unescape_typst(match[1]))
          next
        end

        if match = stripped.match(/^#event\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"(?:\s*,\s*"((?:[^"\\]|\\.)*)")?\s*\)$/)
          date_time = unescape_typst(match[1])
          title = unescape_typst(match[2])
          location = match[3]?.try { |value| unescape_typst(value) } || ""
          payload = event_payload(date_time, title, location)
          nodes << qr_node(current_place, payload)
          next
        end

        if match = stripped.match(/^#contact\(\s*"((?:[^"\\]|\\.)*)"(?:\s*,\s*"((?:[^"\\]|\\.)*)")?(?:\s*,\s*"((?:[^"\\]|\\.)*)")?(?:\s*,\s*"((?:[^"\\]|\\.)*)")?\s*\)$/)
          name = unescape_typst(match[1])
          phone = match[2]?.try { |value| unescape_typst(value) } || ""
          email = match[3]?.try { |value| unescape_typst(value) } || ""
          url = match[4]?.try { |value| unescape_typst(value) } || ""
          payload = contact_payload(name, phone, email, url)
          nodes << qr_node(current_place, payload)
          next
        end

        if stripped.empty?
          nodes << "#linebreak()"
          next
        end

        if match = line.match(/^\s*([#]{1,6})\s+(.+)$/)
          nodes << "#strong(#{typst_string(match[2])})"
          nodes << "#linebreak()"
          next
        end

        nodes << "#(#{typst_string(line)})"
        nodes << "#linebreak()"
      end

      {
        font_id:    normalize_font(font_id),
        body_typst: nodes.join("\n"),
      }
    end

    private def normalize_lines(body : String) : Array(String)
      body
        .gsub(/\r\n?/, "\n")
        .split("\n")
        .map(&.rstrip)
    end

    private def normalize_font(token : String) : String
      normalized = token.downcase
      case normalized
      when "nsm", "ns", "ser", "atk", "ibm"
        normalized
      when "noto-sans-mono"
        "nsm"
      when "noto-sans"
        "ns"
      when "noto-serif"
        "ser"
      when "atkinson"
        "atk"
      when "ibm-plex-mono"
        "ibm"
      else
        "nsm"
      end
    end

    private def normalize_place(raw : String) : String
      expr = raw.strip
      if (expr.starts_with?('"') && expr.ends_with?('"')) || (expr.starts_with?("'") && expr.ends_with?("'"))
        expr = expr[1..-2]
      end

      tokens = expr.downcase.gsub(/\s+/, "").split("+").reject(&.empty?)
      return "right" if tokens.empty?

      if tokens.includes?("none") || tokens.includes?("off") || tokens.includes?("hidden")
        return "none"
      end

      allowed = {
        "left", "right", "top", "bottom", "center", "start", "end",
      }
      filtered = tokens.select { |token| allowed.includes?(token) }
      return "right" if filtered.empty?

      filtered.join(" + ")
    end

    private def qr_node(place : String, payload : String) : String
      "#place(#{place})[#qr(#{typst_string(payload)})]"
    end

    private def event_payload(date_time : String, title : String, location : String) : String
      parsed = parse_typst_datetime(date_time)
      date_part = parsed[:date]
      time_part = parsed[:time]

      compact_date = date_part.gsub("-", "")
      compact_time = time_part.gsub(":", "") + "00"

      lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "DTSTART:#{compact_date}T#{compact_time}",
        "SUMMARY:#{title}",
      ]
      lines << "LOCATION:#{location}" unless location.empty?
      lines << "END:VEVENT"
      lines << "END:VCALENDAR"
      lines.join("\n")
    end

    private def contact_payload(name : String, phone : String, email : String, url : String) : String
      lines = ["BEGIN:VCARD", "VERSION:3.0", "FN:#{name}"]
      lines << "TEL:#{phone}" unless phone.empty?
      lines << "EMAIL:#{email}" unless email.empty?
      lines << "URL:#{url}" unless url.empty?
      lines << "END:VCARD"
      lines.join("\n")
    end

    private def parse_typst_datetime(value : String) : NamedTuple(date: String, time: String)
      if match = value.match(/^(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}))?$/)
        return {date: match[1], time: match[2]? || "09:00"}
      end
      {date: "1970-01-01", time: "09:00"}
    end

    private def unescape_typst(value : String) : String
      value
        .gsub(/\\n/, "\n")
        .gsub(/\\"/, "\"")
        .gsub(/\\\\/, "\\")
    end

    private def build_typst_source(font_id : String, body_typst : String) : String
      layout_path = File.join(ROOT_DIR, "typst/social-badge/layout.typ")
      typ_path = File.join(CACHE_DIR, "_render.typ")
      import_path = Path[layout_path].relative_to(Path[File.dirname(typ_path)]).to_s

      String.build do |io|
        io << "#import " << typst_string(import_path) << ": " << RENDER_FN << ", place, qr\n\n"
        io << "#" << RENDER_FN << "(font_id: " << typst_string(font_id) << ")[\n"
        io << body_typst
        io << "\n]\n"
      end
    end

    private def compile_or_load_svg(cache_key : String, typ_source : String) : String
      FileUtils.mkdir_p(CACHE_DIR)

      typ_path = File.join(CACHE_DIR, "#{cache_key}.typ")
      svg_path = File.join(CACHE_DIR, "#{cache_key}.svg")

      return File.read(svg_path) if File.exists?(svg_path)

      File.write(typ_path, typ_source)
      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run(
        "typst",
        ["compile", "--root", ROOT_DIR, typ_path, svg_path, "--format", "svg"],
        output: output,
        error: error
      )

      unless status.success?
        err = error.to_s
        err = output.to_s if err.empty?
        raise RenderError.new(err.empty? ? "Preview render failed" : err)
      end

      File.read(svg_path)
    end

    private def typst_string(value : String) : String
      escaped = value
        .gsub("\\", "\\\\")
        .gsub("\"", "\\\"")
        .gsub("\n", "\\n")
      "\"#{escaped}\""
    end

    private def typst_available? : Bool
      !!Process.find_executable("typst")
    end
  end
end
