require "digest/sha256"
require "file_utils"
require "json"
require "option_parser"

module SocialBadge
  module TypstLayout
    ROOT_DIR          = File.expand_path("..", __DIR__)
    DEFAULT_CASES     = File.join(ROOT_DIR, "testdata/typst/layout_cases.json")
    DEFAULT_OUTPUT    = File.join(ROOT_DIR, "testdata/typst/out")
    DEFAULT_PPI       = "96"
    DEFAULT_RENDER_FN = "render-badge"

    class ArtifactSpec
      include JSON::Serializable

      getter kind : String
      getter label : String
    end

    class LayoutCase
      include JSON::Serializable

      getter id : String

      @[JSON::Field(default: "")]
      getter description : String = ""

      @[JSON::Field(key: "font_id", default: "nsm")]
      getter font_id : String = "nsm"

      @[JSON::Field(default: "right")]
      getter placement : String = "right"

      @[JSON::Field(default: "UNVERIFIED")]
      getter trust : String = "UNVERIFIED"

      @[JSON::Field(default: "Demo Peer")]
      getter author : String = "Demo Peer"

      @[JSON::Field(default: "now")]
      getter stamp : String = "now"

      @[JSON::Field(default: [] of String)]
      getter lines : Array(String) = [] of String

      @[JSON::Field(default: [] of ArtifactSpec)]
      getter artifacts : Array(ArtifactSpec) = [] of ArtifactSpec

      @[JSON::Field(key: "expected_sha256")]
      property expected_sha256 : String?
    end

    class LayoutSuite
      include JSON::Serializable

      @[JSON::Field(default: "msg_320x240_v1")]
      getter render_spec_version : String = "msg_320x240_v1"

      getter cases : Array(LayoutCase)
    end

    class Runner
      @cases_path : String
      @output_dir : String
      @update : Bool
      @only_case_id : String?

      def initialize(@cases_path : String, @output_dir : String, @update : Bool, @only_case_id : String?)
      end

      def run : Int32
        unless typst_available?
          STDERR.puts "typst binary not found in PATH"
          return 2
        end

        suite = LayoutSuite.from_json(File.read(@cases_path))
        selected_cases = select_cases(suite.cases)

        if selected_cases.empty?
          STDERR.puts "no cases selected"
          return 2
        end

        FileUtils.mkdir_p(@output_dir)
        mismatches = 0

        selected_cases.each do |layout_case|
          typ_path = File.join(@output_dir, "#{layout_case.id}.typ")
          png_path = File.join(@output_dir, "#{layout_case.id}.png")

          File.write(typ_path, build_typst(layout_case, typ_path))
          result = compile_typst(typ_path, png_path)
          unless result[:ok]
            STDERR.puts "compile failed: #{layout_case.id}"
            STDERR.puts result[:error]
            return 1
          end

          actual = Digest::SHA256.hexdigest(File.read(png_path))
          if @update
            layout_case.expected_sha256 = actual
            puts "#{layout_case.id}: updated #{actual}"
            next
          end

          expected = layout_case.expected_sha256
          if expected.nil?
            mismatches += 1
            puts "#{layout_case.id}: missing expected_sha256 (actual #{actual})"
          elsif expected == actual
            puts "#{layout_case.id}: ok #{actual}"
          else
            mismatches += 1
            puts "#{layout_case.id}: mismatch expected #{expected} actual #{actual}"
          end
        end

        if @update
          File.write(@cases_path, suite.to_pretty_json + "\n")
          puts "updated #{@cases_path}"
          return 0
        end

        if mismatches.zero?
          puts "all typst layout cases matched"
          0
        else
          puts "#{mismatches} typst layout case(s) mismatched"
          1
        end
      end

      private def select_cases(all_cases : Array(LayoutCase)) : Array(LayoutCase)
        case_id = @only_case_id
        return all_cases if case_id.nil?
        all_cases.select { |item| item.id == case_id }
      end

      private def compile_typst(typ_path : String, png_path : String) : NamedTuple(ok: Bool, error: String)
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run(
          "typst",
          ["compile", "--root", ROOT_DIR, typ_path, png_path, "--format", "png", "--ppi", DEFAULT_PPI],
          output: output,
          error: error
        )

        if status.success?
          {ok: true, error: ""}
        else
          error_text = error.to_s
          error_text = output.to_s if error_text.empty?
          {ok: false, error: error_text}
        end
      end

      private def build_typst(layout_case : LayoutCase, typ_path : String) : String
        layout_path = File.join(ROOT_DIR, "typst/social-badge/layout.typ")
        import_path = Path[layout_path].relative_to(Path[File.dirname(typ_path)]).to_s
        String.build do |io|
          io << "#import " << typst_string(import_path) << ": " << DEFAULT_RENDER_FN << "\n\n"
          io << "#" << DEFAULT_RENDER_FN << "(\n"
          io << "  trust: " << typst_string(layout_case.trust) << ",\n"
          io << "  author: " << typst_string(layout_case.author) << ",\n"
          io << "  stamp: " << typst_string(layout_case.stamp) << ",\n"
          io << "  font-id: " << typst_string(layout_case.font_id) << ",\n"
          io << "  placement: " << typst_string(layout_case.placement) << ",\n"
          io << "  lines: " << tuple_expr(layout_case.lines.map { |line| typst_string(line) }) << ",\n"
          io << "  artifacts: " << tuple_expr(layout_case.artifacts.map { |item| "(kind: #{typst_string(item.kind)}, label: #{typst_string(item.label)})" }) << ",\n"
          io << ")\n"
        end
      end

      private def tuple_expr(items : Array(String)) : String
        return "()" if items.empty?
        return "(#{items.first},)" if items.size == 1
        "(#{items.join(", ")})"
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
end

cases_path = SocialBadge::TypstLayout::DEFAULT_CASES
output_dir = SocialBadge::TypstLayout::DEFAULT_OUTPUT
update = false
only_case_id : String? = nil

OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run scripts/check_typst_layouts.cr -- [options]"
  parser.on("--cases FILE", "Path to layout cases JSON file") { |value| cases_path = value }
  parser.on("--out DIR", "Output directory for generated typ/png artifacts") { |value| output_dir = value }
  parser.on("--case ID", "Run only a single case ID") { |value| only_case_id = value }
  parser.on("--update", "Update expected_sha256 fields from newly rendered PNGs") { update = true }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end
end

exit SocialBadge::TypstLayout::Runner.new(
  cases_path: cases_path,
  output_dir: output_dir,
  update: update,
  only_case_id: only_case_id
).run
