#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "../fastlane/ios_release_version"

PRODUCTS = {
  "study" => ["study-nurio-mobile", "NurioStudy"],
  "leaders" => ["leaders-nurio-mobile", "NurioStudyLeader"]
}.freeze

class StudyVersionBump
  def initialize(root, product)
    directory, target = PRODUCTS.fetch(product)
    @ios_path = File.join(root, directory, "ios/#{target}.xcodeproj/project.pbxproj")
    @android_path = File.join(root, directory, "android/app/build.gradle.kts")
    @ios = IosReleaseVersion.new(@ios_path, target_name: target)
    @android_original = File.read(@android_path)
    @android_name = read_one(/\bversionName\s*=\s*"([^"]+)"/, "versionName")
    @android_code = Integer(read_one(/\bversionCode\s*=\s*(\d+)/, "versionCode"))
    raise "Invalid Android versionName" unless @android_name.match?(/\A\d+\.\d+\.\d+\z/)
  end

  attr_reader :ios_path, :android_path

  def plan(kind)
    if kind == "build"
      ios_name = @ios.version
      android_name = @android_name
      ios_build = @ios.build + 1
    else
      highest = [@ios.version, @android_name].max_by { |name| name.split(".").map(&:to_i) }
      major, minor, patch = highest.split(".").map(&:to_i)
      ios_name = android_name = case kind
      when "major" then "#{major + 1}.0.0"
      when "minor" then "#{major}.#{minor + 1}.0"
      when "patch" then "#{major}.#{minor}.#{patch + 1}"
      else raise ArgumentError, "Expected build, major, minor, or patch"
      end
      ios_build = 1
    end
    {
      ios: { from: "#{@ios.version} (#{@ios.build})", name: ios_name, build: ios_build },
      android: { from: "#{@android_name} (#{@android_code})", name: android_name, code: @android_code + 1 }
    }
  end

  def apply(plan)
    raise "Android version file changed" unless File.read(@android_path) == @android_original

    android = @android_original.sub(/\bversionName\s*=\s*"[^"]+"/, "versionName = \"#{plan[:android][:name]}\"")
                                .sub(/\bversionCode\s*=\s*\d+/, "versionCode = #{plan[:android][:code]}")
    @ios.update(version: plan[:ios][:name], build: plan[:ios][:build])
    begin
      File.write(@android_path, android)
    rescue StandardError
      @ios.restore
      raise
    end
  end

  private

  def read_one(pattern, label)
    values = @android_original.scan(pattern).flatten
    raise "Expected exactly one Android #{label}" unless values.length == 1

    values.first
  end
end

if $PROGRAM_NAME == __FILE__
  dry_run = false
  parser = OptionParser.new do |options|
    options.banner = "Usage: ruby scripts/bump-study-versions.rb study|leaders [build|major|minor|patch] [--dry-run]"
    options.on("--dry-run", "Show versions without changing files") { dry_run = true }
  end
  parser.parse!
  product = ARGV.shift
  kind = ARGV.shift || "patch"
  parser.abort(parser.to_s) unless PRODUCTS.key?(product) && %w[build major minor patch].include?(kind) && ARGV.empty?

  root = File.expand_path("..", __dir__)
  bump = StudyVersionBump.new(root, product)
  unless dry_run
    [bump.ios_path, bump.android_path].each do |path|
      relative_path = path.delete_prefix("#{root}/")
      next if system("git", "-C", root, "diff", "--quiet", "--", relative_path) &&
              system("git", "-C", root, "diff", "--cached", "--quiet", "--", relative_path)

      abort "#{relative_path} has pending changes; commit or set them aside before bumping"
    end
  end

  plan = bump.plan(kind)
  puts "#{product} iOS:     #{plan[:ios][:from]} -> #{plan[:ios][:name]} (#{plan[:ios][:build]})"
  puts "#{product} Android: #{plan[:android][:from]} -> #{plan[:android][:name]} (#{plan[:android][:code]})"
  if dry_run
    puts "Dry run; no files changed."
  else
    bump.apply(plan)
    puts "Updated both version files. Check the Android code against Play before upload."
  end
end
