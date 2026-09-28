#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "../fastlane/ios_release_version"

PRODUCTS = {
  "study" => ["study-nurio-mobile", "NurioStudy"],
  "leaders" => ["leaders-nurio-mobile", "NurioStudyLeader"]
}.freeze

class StudyVersionBump
  def initialize(root, product, platform: "both")
    raise ArgumentError, "Expected ios, android, or both" unless %w[ios android both].include?(platform)

    @platform = platform
    directory, target = PRODUCTS.fetch(product)
    @ios_path = File.join(root, directory, "ios/#{target}.xcodeproj/project.pbxproj")
    @android_path = File.join(root, directory, "android/app/build.gradle.kts")
    @ios = IosReleaseVersion.new(@ios_path, target_name: target) if %w[ios both].include?(platform)
    if %w[android both].include?(platform)
      @android_original = File.read(@android_path)
      @android_name = read_one(/\bversionName\s*=\s*"([^"]+)"/, "versionName")
      @android_code = Integer(read_one(/\bversionCode\s*=\s*(\d+)/, "versionCode"))
      raise "Invalid Android versionName" unless @android_name.match?(/\A\d+\.\d+\.\d+\z/)
    end
  end

  attr_reader :ios_path, :android_path

  def paths
    { "ios" => [ios_path], "android" => [android_path], "both" => [ios_path, android_path] }.fetch(@platform)
  end

  def plan(kind)
    raise ArgumentError, "Expected build, major, minor, or patch" unless %w[build major minor patch].include?(kind)

    versions = [@ios&.version, @android_name].compact
    base = versions.max_by { |name| name.split(".").map(&:to_i) }
    next_name = advance(base, kind) unless kind == "build"
    plan = {}
    if @ios
      plan[:ios] = {
        from: "#{@ios.version} (#{@ios.build})",
        name: next_name || @ios.version,
        build: next_name ? 1 : @ios.build + 1
      }
    end
    if @android_original
      plan[:android] = {
        from: "#{@android_name} (#{@android_code})",
        name: next_name || @android_name,
        code: @android_code + 1
      }
    end
    plan
  end

  def apply(plan)
    if plan[:android]
      raise "Android version file changed" unless File.read(@android_path) == @android_original
      android = @android_original.sub(/\bversionName\s*=\s*"[^"]+"/, "versionName = \"#{plan[:android][:name]}\"")
                                  .sub(/\bversionCode\s*=\s*\d+/, "versionCode = #{plan[:android][:code]}")
    end

    @ios.update(version: plan[:ios][:name], build: plan[:ios][:build]) if plan[:ios]
    begin
      File.write(@android_path, android) if plan[:android]
    rescue StandardError
      @ios&.restore
      raise
    end
  end

  private

  def advance(name, kind)
    major, minor, patch = name.split(".").map(&:to_i)
    case kind
    when "major" then "#{major + 1}.0.0"
    when "minor" then "#{major}.#{minor + 1}.0"
    when "patch" then "#{major}.#{minor}.#{patch + 1}"
    end
  end

  def read_one(pattern, label)
    values = @android_original.scan(pattern).flatten
    raise "Expected exactly one Android #{label}" unless values.length == 1

    values.first
  end
end

if $PROGRAM_NAME == __FILE__
  dry_run = false
  platform = "both"
  parser = OptionParser.new do |options|
    options.banner = "Usage: ruby scripts/bump-study-versions.rb study|leaders [build|major|minor|patch] [--platform ios|android|both] [--dry-run]"
    options.on("--dry-run", "Show versions without changing files") { dry_run = true }
    options.on("--platform PLATFORM", %w[ios android both], "Bump one platform or both") { |value| platform = value }
  end
  parser.parse!
  product = ARGV.shift
  kind = ARGV.shift || "patch"
  parser.abort(parser.to_s) unless PRODUCTS.key?(product) && %w[build major minor patch].include?(kind) && ARGV.empty?

  root = File.expand_path("..", __dir__)
  bump = StudyVersionBump.new(root, product, platform: platform)
  unless dry_run
    bump.paths.each do |path|
      relative_path = path.delete_prefix("#{root}/")
      next if system("git", "-C", root, "diff", "--quiet", "--", relative_path) &&
              system("git", "-C", root, "diff", "--cached", "--quiet", "--", relative_path)

      abort "#{relative_path} has pending changes; commit or set them aside before bumping"
    end
  end

  plan = bump.plan(kind)
  puts "#{product} iOS:     #{plan[:ios][:from]} -> #{plan[:ios][:name]} (#{plan[:ios][:build]})" if plan[:ios]
  puts "#{product} Android: #{plan[:android][:from]} -> #{plan[:android][:name]} (#{plan[:android][:code]})" if plan[:android]
  if dry_run
    puts "Dry run; no files changed."
  else
    bump.apply(plan)
    puts "Updated #{platform} version file#{platform == 'both' ? 's' : ''}."
    puts "Check the Android code against Play before upload." if plan[:android]
  end
end
