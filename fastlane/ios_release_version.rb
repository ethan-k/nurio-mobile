require "xcodeproj"

# Change only the Nurio app's build configurations, preserving the test target
# and the formatting of this hand-maintained project file.
class IosReleaseVersion
  CLOSED_STATES = %w[
    ACCEPTED PENDING_APPLE_RELEASE PENDING_DEVELOPER_RELEASE
    PROCESSING_FOR_DISTRIBUTION READY_FOR_DISTRIBUTION REPLACED_WITH_NEW_VERSION
    PROCESSING_FOR_APP_STORE READY_FOR_SALE PREORDER_READY_FOR_SALE
    DEVELOPER_REMOVED_FROM_SALE REMOVED_FROM_SALE
  ].freeze

  attr_reader :path, :original, :bumped

  def initialize(path)
    @path = path
    @original = File.read(path)
    project = Xcodeproj::Project.open(File.dirname(path))
    target = project.targets.find { |item| item.name == "Nurio" }
    raise "Nurio app target is missing" unless target

    @settings = target.build_configurations.to_h do |config|
      [config.uuid, config.build_settings.slice("MARKETING_VERSION", "CURRENT_PROJECT_VERSION")]
    end
    @settings.values.each do |settings|
      raise "Invalid iOS marketing version" unless settings["MARKETING_VERSION"].to_s.match?(/\A\d+\.\d+(?:\.\d+)?\z/)
      raise "Invalid iOS build number" unless settings["CURRENT_PROJECT_VERSION"].to_s.match?(/\A\d+\z/)
    end
    raise "Nurio build configurations have different versions" unless @settings.values.uniq.one?
  end

  def version = @settings.values.first.fetch("MARKETING_VERSION")
  def build = @settings.values.first.fetch("CURRENT_PROJECT_VERSION").to_i

  def self.next_patch(version)
    parts = version.split(".").map(&:to_i)
    "#{parts[0]}.#{parts[1]}.#{parts.fetch(2, 0) + 1}"
  end

  def self.open_version(current, store_versions)
    closed = store_versions.select { |item| CLOSED_STATES.include?(item.app_version_state || item.app_store_state) }
    floor = closed.map { |item| item.version_string }.max_by { |value| Gem::Version.new(value) }
    floor && Gem::Version.new(current) <= Gem::Version.new(floor) ? next_patch(floor) : current
  end

  def update(version:, build:)
    current = File.read(path)
    raise "Xcode project changed during release; refusing to absorb other edits" unless current == (bumped || original)

    @new_settings = { "MARKETING_VERSION" => version, "CURRENT_PROJECT_VERSION" => build.to_s }
    @bumped = rewrite(current) { |_uuid, key, _current| @new_settings.fetch(key) }
    File.write(path, bumped)
  end

  def restore
    return unless bumped

    restored = rewrite(File.read(path)) do |uuid, key, current|
      current == @new_settings.fetch(key) ? @settings.fetch(uuid).fetch(key) : current
    end
    File.write(path, restored)
  end

  private

  def rewrite(contents)
    @settings.each_key do |uuid|
      pattern = /(\b#{Regexp.escape(uuid)} \/\* [^\n]* \*\/ = \{\n)(.*?)(^\t\t\};)/m
      raise "Missing Xcode build configuration #{uuid}" unless contents.match?(pattern)

      contents = contents.sub(pattern) do
        prefix, body, suffix = Regexp.last_match.captures
        body = body.gsub(/\b(MARKETING_VERSION|CURRENT_PROJECT_VERSION) = ([^;]+);/) do
          key, current = Regexp.last_match.captures
          "#{key} = #{yield(uuid, key, current)};"
        end
        prefix + body + suffix
      end
    end
    contents
  end
end
