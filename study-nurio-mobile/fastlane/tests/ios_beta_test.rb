require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

class StudyBetaHarness
  module UI
    def self.message(*) = nil
    def self.success(*) = nil
    def self.user_error!(message) = raise(message)
  end

  class << self
    attr_reader :lanes

    def platform(name)
      @platform = name
      yield
    end

    def lane(name, &block)
      (@lanes ||= {})[[@platform, name]] = block
    end

    def desc(*) = nil
    def before_all(*) = nil
    def after_all(*) = nil
    def error(*) = nil
  end

  fastfile = File.expand_path("../Fastfile", __dir__)
  class_eval File.read(fastfile), fastfile

  attr_accessor :versions, :latest_build, :on_build, :on_upload
  attr_reader :builds, :uploads

  def nurio_asc_api_key = {}
  def study_ios_store_versions(api_key:) = versions
  def latest_testflight_build_number(**) = latest_build || 0

  def build
    @builds = (@builds || 0) + 1
    on_build&.call
  end

  def upload_to_testflight(**)
    @uploads = (@uploads || 0) + 1
    on_upload&.call
  end

  def sh(command)
    output, status = Open3.capture2e(command)
    raise output unless status.success?
    output
  end

  def run_beta
    instance_exec(&self.class.lanes.fetch([:ios, :beta]))
  end
end

class StudyIosBetaTest < Minitest::Test
  Version = Struct.new(:version_string, :app_version_state, :app_store_state)

  def setup
    @root = Dir.mktmpdir("study-ios-beta-")
    @prior_dir = Dir.pwd
    @project = File.join(@root, "ios/NurioStudy.xcodeproj/project.pbxproj")
    FileUtils.mkdir_p(File.dirname(@project))
    FileUtils.mkdir_p(File.join(@root, "fastlane"))
    FileUtils.cp(File.expand_path("../../ios/NurioStudy.xcodeproj/project.pbxproj", __dir__), @project)
    Dir.chdir(@root)
    git("init", "-q")
    git("config", "user.name", "Release Test")
    git("config", "user.email", "release-test@example.invalid")
    git("config", "core.hooksPath", "/dev/null")
    git("config", "commit.gpgsign", "false")
    git("add", "ios/NurioStudy.xcodeproj/project.pbxproj")
    git("commit", "-qm", "baseline")
    @original = File.read(@project)
    Dir.chdir(File.join(@root, "fastlane"))
    @lane = StudyBetaHarness.new
    @lane.versions = [Version.new("1.0.1", "READY_FOR_DISTRIBUTION")]
  end

  def teardown
    Dir.chdir(@prior_dir)
    FileUtils.remove_entry(@root)
  end

  def git(*args)
    output, status = Open3.capture2e("git", "-C", @root, *args)
    raise output unless status.success?
    output
  end

  def version
    IosReleaseVersion.new(@project, target_name: "NurioStudy")
  end

  def test_released_local_version_advances_before_build_and_commits_after_upload
    @lane.on_build = -> { assert_equal "1.0.2", version.version }
    @lane.run_beta
    assert_equal "1.0.2", version.version
    assert_equal 1, version.build
    assert_equal 1, @lane.uploads
    assert_equal "ios/NurioStudy.xcodeproj/project.pbxproj", git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").strip
  end

  def test_open_version_retains_name_and_uses_next_testflight_build
    @lane.versions = [Version.new("1.0.1", "PREPARE_FOR_SUBMISSION")]
    @lane.latest_build = 4
    @lane.run_beta
    assert_equal "1.0.1", version.version
    assert_equal 5, version.build
  end

  def test_newer_released_version_advances_from_store_version
    @lane.versions = [Version.new("1.0.3", "READY_FOR_DISTRIBUTION")]
    @lane.run_beta
    assert_equal "1.0.4", version.version
  end

  def test_closed_train_rejection_rebuilds_once_on_next_patch
    @lane.on_upload = -> { raise "Invalid Pre-Release Train (90186)" if @lane.uploads == 1 }
    @lane.run_beta
    assert_equal 2, @lane.builds
    assert_equal "1.0.3", version.version
  end

  def test_store_failure_stops_before_build
    @lane.versions = nil
    @lane.define_singleton_method(:study_ios_store_versions) { |**| raise "store unavailable" }
    assert_raises(RuntimeError) { @lane.run_beta }
    assert_nil @lane.builds
    assert_equal @original, File.read(@project)
  end

  def test_build_failure_restores_original_project
    @lane.on_build = -> { raise "build failed" }
    assert_raises(RuntimeError) { @lane.run_beta }
    assert_equal @original, File.read(@project)
    assert_nil @lane.uploads
  end

  def test_upload_failure_restores_original_project
    @lane.on_upload = -> { raise "upload failed" }
    assert_raises(RuntimeError) { @lane.run_beta }
    assert_equal @original, File.read(@project)
  end

  def test_existing_version_edits_stop_before_store_lookup
    File.write(@project, @original + "\n")
    assert_raises(RuntimeError) { @lane.run_beta }
    assert_nil @lane.builds
  end
end
