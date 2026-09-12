require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"

# Execute the actual beta lane with local Git, replacing only store/build calls
# and credentials. Nothing in this suite builds an app or contacts Google Play.
class AndroidBetaHarness
  module UI
    def self.message(*) = nil
    def self.success(*) = nil
    def self.important(*) = nil
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

  class_eval File.read(File.expand_path("../Fastfile", __dir__)), File.expand_path("../Fastfile", __dir__)

  module NurioCredentials
    def self.require!(*) = nil
    def self.play_json_key_data = "test credentials"
  end

  attr_accessor :on_build, :on_upload, :fail_commit
  attr_reader :uploaded

  def build
    on_build&.call
  end

  def upload_to_play_store(**)
    on_upload&.call
    @uploaded = true
  end

  def google_play_track_version_codes(**) = [19]

  def sh(command)
    raise "commit failed" if fail_commit && command.include?(" commit ")

    output, status = Open3.capture2e(command)
    raise output unless status.success?

    output
  end

  def run_beta
    instance_exec(&self.class.lanes.fetch([:android, :beta]))
  end
end

class ReleaseLaneTest < Minitest::Test
  ORIGINAL = "android {\n  versionCode = 19\n  versionName = \"1.0.14\"\n}\n"
  BUMPED = ORIGINAL.sub("19", "20").sub("1.0.14", "1.0.15")

  def setup
    @root = Dir.mktmpdir("nurio-android-beta-test-")
    @previous_dir = Dir.pwd
    FileUtils.mkdir_p(File.join(@root, "android/app"))
    FileUtils.mkdir_p(File.join(@root, "fastlane"))
    @gradle = File.join(@root, "android/app/build.gradle.kts")
    File.write(@gradle, ORIGINAL)
    Dir.chdir(@root)
    git("init", "-q")
    git("config", "user.name", "Release Test")
    git("config", "user.email", "release-test@example.invalid")
    git("config", "core.hooksPath", "/dev/null")
    git("config", "commit.gpgsign", "false")
    git("add", "android/app/build.gradle.kts")
    git("commit", "-qm", "baseline")
    @head = git("rev-parse", "HEAD").strip
    Dir.chdir(File.join(@root, "fastlane"))
    @lane = AndroidBetaHarness.new
  end

  def teardown
    Dir.chdir(@previous_dir)
    FileUtils.remove_entry(@root)
  end

  def git(*args)
    output, status = Open3.capture2e("git", "-C", @root, *args)
    raise output unless status.success?

    output
  end

  def assert_rolled_back
    assert_equal ORIGINAL, File.read(@gradle)
    assert_equal @head, git("rev-parse", "HEAD").strip
    assert_empty git("status", "--porcelain", "--", "android/app/build.gradle.kts")
  end
end

class AndroidBetaTest < ReleaseLaneTest
  def test_success_commits_only_version_file_and_preserves_other_work
    File.write(File.join(@root, "other.txt"), "staged work")
    git("add", "other.txt")
    File.write(File.join(@root, "other.txt"), "unstaged work")
    @lane.on_upload = -> { assert_equal @head, git("rev-parse", "HEAD").strip }

    @lane.run_beta

    assert @lane.uploaded
    assert_equal BUMPED, File.read(@gradle)
    assert_equal "chore(release): bump Nurio Android to 1.0.15 (20)", git("log", "-1", "--format=%s").strip
    assert_equal "android/app/build.gradle.kts", git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").strip
    assert_equal "other.txt", git("diff", "--cached", "--name-only").strip
    assert_equal "unstaged work", File.read(File.join(@root, "other.txt"))
  end

  def test_build_failure_restores_versions_without_upload_or_commit
    @lane.on_build = -> { raise "build failed" }
    assert_equal "build failed", assert_raises(RuntimeError) { @lane.run_beta }.message
    refute @lane.uploaded
    assert_rolled_back
  end

  def test_upload_failure_restores_versions_without_commit
    @lane.on_upload = -> { raise "upload failed" }
    assert_equal "upload failed", assert_raises(RuntimeError) { @lane.run_beta }.message
    assert_rolled_back
  end

  def test_interrupt_restores_versions
    @lane.on_build = -> { raise Interrupt }
    assert_raises(Interrupt) { @lane.run_beta }
    assert_rolled_back
  end

  def test_commit_failure_keeps_successfully_uploaded_version
    @lane.fail_commit = true
    assert_equal "commit failed", assert_raises(RuntimeError) { @lane.run_beta }.message
    assert @lane.uploaded
    assert_equal BUMPED, File.read(@gradle)
    assert_equal @head, git("rev-parse", "HEAD").strip
  end

  def test_rollback_preserves_edits_made_during_build
    @lane.on_build = lambda do
      File.write(@gradle, File.read(@gradle) + "// independent edit\n")
      raise "build failed"
    end
    assert_raises(RuntimeError) { @lane.run_beta }
    assert_equal ORIGINAL + "// independent edit\n", File.read(@gradle)
  end

  def test_rollback_preserves_a_concurrently_changed_version
    @lane.on_build = lambda do
      File.write(@gradle, File.read(@gradle).sub("versionCode = 20", "versionCode = 25"))
      raise "build failed"
    end
    assert_raises(RuntimeError) { @lane.run_beta }
    assert_equal ORIGINAL.sub("versionCode = 19", "versionCode = 25"), File.read(@gradle)
  end

  def test_success_with_concurrent_edits_does_not_commit_them
    @lane.on_build = -> { File.write(@gradle, BUMPED + "// independent edit\n") }
    error = assert_raises(RuntimeError) { @lane.run_beta }
    assert_match(/Play upload succeeded/, error.message)
    assert @lane.uploaded
    assert_equal BUMPED + "// independent edit\n", File.read(@gradle)
    assert_equal @head, git("rev-parse", "HEAD").strip
  end

  def test_preexisting_gradle_edits_are_rejected_and_preserved
    File.write(@gradle, ORIGINAL + "// existing work\n")
    assert_raises(RuntimeError) { @lane.run_beta }
    assert_equal ORIGINAL + "// existing work\n", File.read(@gradle)
    refute @lane.uploaded
  end
end
