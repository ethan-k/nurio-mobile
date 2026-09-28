require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../bump-study-versions"

class StudyVersionBumpTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("study-version-bump-")
    @source = File.expand_path("../..", __dir__)
    PRODUCTS.each_value do |directory, target|
      ios = "#{directory}/ios/#{target}.xcodeproj/project.pbxproj"
      android = "#{directory}/android/app/build.gradle.kts"
      [ios, android].each do |path|
        FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
        FileUtils.cp(File.join(@source, path), File.join(@root, path))
      end
    end
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_study_patch_uses_higher_platform_version
    bump = StudyVersionBump.new(@root, "study")
    current_code = File.read(bump.android_path).match(/versionCode = (\d+)/)[1].to_i
    plan = bump.plan("patch")
    assert_equal "1.0.3", plan[:ios][:name]
    assert_equal "1.0.3", plan[:android][:name]
    assert_equal current_code + 1, plan[:android][:code]
    bump.apply(plan)
    assert_equal "1.0.3", IosReleaseVersion.new(bump.ios_path, target_name: "NurioStudy").version
    assert_match(/versionName = "1.0.3"/, File.read(bump.android_path))
  end

  def test_leader_bump_changes_only_app_target
    bump = StudyVersionBump.new(@root, "leaders")
    original = File.read(bump.ios_path)
    bump.apply(bump.plan("patch"))
    assert_equal "1.0.1", IosReleaseVersion.new(bump.ios_path, target_name: "NurioStudyLeader").version
    assert_equal original.scan(/MARKETING_VERSION = 1\.0\.0;/).length - 2,
                 File.read(bump.ios_path).scan(/MARKETING_VERSION = 1\.0\.0;/).length
  end

  def test_build_bump_keeps_marketing_names
    bump = StudyVersionBump.new(@root, "leaders")
    plan = bump.plan("build")
    assert_equal "1.0.0", plan[:ios][:name]
    assert_equal "1.0.0", plan[:android][:name]
    assert_equal 2, plan[:ios][:build]
    assert_equal 2, plan[:android][:code]
  end

  def test_study_ios_bumps_independently_without_android_file
    android = File.join(@root, "study-nurio-mobile/android/app/build.gradle.kts")
    File.delete(android)
    bump = StudyVersionBump.new(@root, "study", platform: "ios")
    assert_equal [bump.ios_path], bump.paths
    plan = bump.plan("patch")
    assert_equal [:ios], plan.keys
    assert_equal "1.0.2", plan[:ios][:name]
    bump.apply(plan)
    assert_equal "1.0.2", IosReleaseVersion.new(bump.ios_path, target_name: "NurioStudy").version
  end

  def test_study_android_bumps_independently_without_ios_file
    ios = File.join(@root, "study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj")
    File.delete(ios)
    bump = StudyVersionBump.new(@root, "study", platform: "android")
    assert_equal [bump.android_path], bump.paths
    plan = bump.plan("patch")
    assert_equal [:android], plan.keys
    assert_equal "1.0.3", plan[:android][:name]
    bump.apply(plan)
    assert_match(/versionName = "1.0.3"/, File.read(bump.android_path))
  end
end
