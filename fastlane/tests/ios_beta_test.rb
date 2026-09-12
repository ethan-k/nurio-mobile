require_relative "android_beta_test"

class AndroidBetaHarness
  attr_accessor :store_versions, :testflight_build, :store_error
  attr_reader :build_queries, :upload_attempts

  def nurio_asc_api_key = {}

  def nurio_ios_store_versions(api_key:)
    raise store_error if store_error
    store_versions || []
  end

  def latest_testflight_build_number(**options)
    (@build_queries ||= []) << options
    testflight_build || 0
  end

  def upload_to_testflight(**)
    @upload_attempts = (@upload_attempts || 0) + 1
    on_upload&.call
    @uploaded = true
  end

  def run_ios_beta
    instance_exec(&self.class.lanes.fetch([:ios, :beta]))
  end
end

class IosBetaTest < ReleaseLaneTest
  Version = Struct.new(:version_string, :app_version_state, :app_store_state)

  def setup
    super
    @project = File.join(@root, "ios/Nurio.xcodeproj/project.pbxproj")
    FileUtils.mkdir_p(File.dirname(@project))
    FileUtils.cp(File.expand_path("../../ios/Nurio.xcodeproj/project.pbxproj", __dir__), @project)
    IosReleaseVersion.new(@project).update(version: "1.0.14", build: 1)
    git("add", "ios/Nurio.xcodeproj/project.pbxproj")
    git("commit", "-qm", "iOS baseline")
    @head = git("rev-parse", "HEAD").strip
    @original_project = File.read(@project)
    @lane.store_versions = [Version.new("1.0.14", "READY_FOR_DISTRIBUTION")]
  end

  def assert_ios_version(version, build)
    file = IosReleaseVersion.new(@project)
    assert_equal version, file.version
    assert_equal build, file.build
    # Changing the app's version must not change the NurioTests target.
    original_tests = @original_project.scan(/MARKETING_VERSION = 1\.0\.1;/).size
    assert_equal original_tests, File.read(@project).scan(/MARKETING_VERSION = 1\.0\.1;/).size
  end

  def assert_ios_rollback
    assert_equal @original_project, File.read(@project)
    assert_equal @head, git("rev-parse", "HEAD").strip
  end

  def test_approved_train_advances_patch_and_commits_after_upload
    @lane.on_upload = -> { assert_equal @head, git("rev-parse", "HEAD").strip }
    @lane.run_ios_beta
    assert_ios_version "1.0.15", 1
    assert_equal "1.0.15", @lane.build_queries.first.fetch(:version)
    assert_equal "chore(release): bump Nurio iOS to 1.0.15 (1)", git("log", "-1", "--format=%s").strip
    assert_equal "ios/Nurio.xcodeproj/project.pbxproj", git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").strip
  end

  def test_open_train_keeps_marketing_version_and_uses_unused_build
    @lane.store_versions = [Version.new("1.0.14", "PREPARE_FOR_SUBMISSION")]
    @lane.testflight_build = 3
    @lane.run_ios_beta
    assert_ios_version "1.0.14", 4
  end

  def test_store_query_failure_stops_before_build_and_file_changes
    @lane.store_error = "App Store Connect unavailable"
    @lane.on_build = -> { flunk "must not build without store state" }
    assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_ios_rollback
  end

  def test_build_failure_rolls_back
    @lane.on_build = -> { raise "build failed" }
    assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_ios_rollback
  end

  def test_upload_failure_rolls_back_without_retrying_unrelated_errors
    @lane.on_upload = -> { raise "authentication failed" }
    assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_equal 1, @lane.upload_attempts
    assert_ios_rollback
  end

  def test_closed_train_rejection_rebuilds_once_with_next_version
    builds = []
    @lane.on_build = -> { builds << IosReleaseVersion.new(@project).version }
    @lane.on_upload = -> { raise "Invalid Pre-Release Train (90186)" if @lane.upload_attempts == 1 }
    @lane.run_ios_beta
    assert_equal ["1.0.15", "1.0.16"], builds
    assert_ios_version "1.0.16", 1
  end

  def test_second_closed_train_rejection_restores_original_version
    @lane.on_upload = -> { raise "Invalid Pre-Release Train (90186)" }
    assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_equal 2, @lane.upload_attempts
    assert_ios_rollback
  end

  def test_interrupt_rolls_back
    @lane.on_build = -> { raise Interrupt }
    assert_raises(Interrupt) { @lane.run_ios_beta }
    assert_ios_rollback
  end

  def test_commit_failure_retains_uploaded_version
    @lane.fail_commit = true
    assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert @lane.uploaded
    assert_ios_version "1.0.15", 1
  end

  def test_rollback_preserves_independent_edits
    @lane.on_build = lambda do
      File.write(@project, File.read(@project) + "// independent edit\n")
      raise "build failed"
    end
    assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_equal @original_project + "// independent edit\n", File.read(@project)
  end

  def test_first_upload_keeps_local_version_and_build
    @lane.store_versions = []
    @lane.run_ios_beta
    assert_ios_version "1.0.14", 1
    assert_equal @head, git("rev-parse", "HEAD").strip
  end

  def test_success_does_not_commit_changes_staged_during_upload
    @lane.on_upload = -> { git("add", "ios/Nurio.xcodeproj/project.pbxproj") }
    error = assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_match(/was staged during release/, error.message)
    assert @lane.uploaded
    assert_ios_version "1.0.15", 1
    assert_equal @head, git("rev-parse", "HEAD").strip
  end

  def test_success_does_not_commit_independent_project_edits
    @lane.on_build = -> { File.write(@project, File.read(@project) + "// independent edit\n") }
    error = assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_match(/TestFlight upload succeeded/, error.message)
    assert @lane.uploaded
    assert_equal @head, git("rev-parse", "HEAD").strip
  end

  def test_retry_does_not_absorb_independent_project_edits
    @lane.on_upload = lambda do
      File.write(@project, File.read(@project) + "// independent edit\n")
      raise "Invalid Pre-Release Train (90186)"
    end
    error = assert_raises(RuntimeError) { @lane.run_ios_beta }
    assert_match(/refusing to absorb other edits/, error.message)
    assert_equal @original_project + "// independent edit\n", File.read(@project)
  end

  def test_selects_version_above_highest_approved_train
    versions = [Version.new("1.0.9", "READY_FOR_DISTRIBUTION"), Version.new("1.0.14", "PENDING_DEVELOPER_RELEASE")]
    assert_equal "1.0.15", IosReleaseVersion.open_version("1.0.10", versions)
    assert_equal "1.1.0", IosReleaseVersion.open_version("1.1.0", versions)
    assert_equal "1.0.15", IosReleaseVersion.open_version("1.0.14", [Version.new("1.0.14", nil, "READY_FOR_SALE")])
  end
end
