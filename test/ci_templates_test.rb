##[>] 🤖🤖
require "minitest/autorun"
require "yaml"

CONFIG_DIR = File.expand_path("../consumer-repo-config", __dir__)

TEMPLATES = {
  "CheProfileBase" => "ci/templates/CheProfileBase.gitlab-ci.yml",
  "CheProfileDryRun" => "ci/templates/CheProfileDryRun.gitlab-ci.yml",
  "CheProfileApply" => "ci/templates/CheProfileApply.gitlab-ci.yml",
  "EmitEvents" => "ci/templates/EmitEvents.gitlab-ci.yml",
  "FilesTrackedVerify" => "files-generation/templates/FilesTrackedVerify.gitlab-ci.yml",
  "PrecommitChanged" => "precommit-lefthook/templates/PrecommitChanged.gitlab-ci.yml",
  "PrecommitAll" => "precommit-lefthook/templates/PrecommitAll.gitlab-ci.yml",
  "TagMint" => "release/templates/TagMint.gitlab-ci.yml"
}.freeze

def template(name)
  YAML.load_stream(File.read(File.join(CONFIG_DIR, TEMPLATES.fetch(name))))
end

def spec_and_body(name)
  docs = template(name)
  raise "#{name}: want a spec header then a body" unless docs.length == 2

  docs
end

def job(name)
  spec_and_body(name).last.values.first
end

class MatrixTemplateSpecTest < Minitest::Test
  MATRIX_TEMPLATES = %w[CheProfileDryRun CheProfileApply].freeze

  def test_declares_required_profiles_input
    MATRIX_TEMPLATES.each do |name|
      profiles = spec_and_body(name).first.dig("spec", "inputs", "profiles")

      assert_equal "array", profiles["type"], name
      refute profiles.key?("default"), "#{name}: profiles must stay required"
    end
  end

  def test_fans_out_over_profiles_and_arches
    MATRIX_TEMPLATES.each do |name|
      matrix = job(name).dig("parallel", "matrix").first

      assert_equal "$[[ inputs.profiles ]]", matrix["CHE_PROFILE"], name
      assert_equal "$[[ inputs.arches ]]", matrix["ARCH"], name
    end
  end

  def test_extends_a_body_the_base_template_defines
    bases = template("CheProfileBase").first.keys

    MATRIX_TEMPLATES.each do |name|
      extended = job(name)["extends"]
      as_user = spec_and_body(name).first.dig("spec", "inputs", "as_user", "options")

      as_user.each do |value|
        assert_includes bases, extended.sub("$[[ inputs.as_user ]]", value), name
      end
    end
  end

  def test_gates_every_job_on_the_enabled_input
    MATRIX_TEMPLATES.each do |name|
      first_rule = job(name)["rules"].first

      assert_equal "never", first_rule["when"], name
      assert_includes first_rule["if"], "inputs.enabled", name
    end
  end
end

class GenericJobTemplateTest < Minitest::Test
  GENERIC_TEMPLATES = %w[FilesTrackedVerify PrecommitChanged PrecommitAll TagMint].freeze

  def test_every_job_carries_the_generic_prefix
    GENERIC_TEMPLATES.each do |name|
      job_name = spec_and_body(name).last.keys.first

      assert job_name.start_with?("generic:"), "#{name}: #{job_name}"
    end
  end

  def test_every_input_defaults
    GENERIC_TEMPLATES.each do |name|
      spec_and_body(name).first.dig("spec", "inputs").each do |key, input|
        assert input.key?("default"), "#{name}: #{key} must default"
      end
    end
  end

  def test_every_job_bootstraps_its_payload_without_a_consumer_make_target
    GENERIC_TEMPLATES.each do |name|
      bootstrap = job(name)["script"].first

      refute_includes bootstrap, "make ", name
      assert_includes bootstrap, "--profiles=genericSetup", name
    end
  end

  def test_every_job_ends_on_its_generic_make_target
    GENERIC_TEMPLATES.each do |name|
      assert_match(/\Amake generic-/, job(name)["script"].last, name)
    end
  end
end

class FilesTrackedVerifyTest < Minitest::Test
  def rules
    job("FilesTrackedVerify")["rules"]
  end

  def test_never_runs_on_a_tag
    assert_equal({ "if" => "$CI_COMMIT_TAG", "when" => "never" }, rules.first)
  end

  def test_runs_on_merge_requests
    assert_includes rules.map { |r| r["if"] }, '$CI_PIPELINE_SOURCE == "merge_request_event"'
  end

  def test_is_manual_and_allowed_to_fail_on_the_default_branch
    main = rules.find { |r| r["if"] == "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH" }

    assert_equal "manual", main["when"]
    assert main["allow_failure"]
  end
end

class PrecommitTemplatesTest < Minitest::Test
  def test_changed_runs_only_on_merge_requests_with_full_history
    changed = job("PrecommitChanged")

    assert_equal ['$CI_PIPELINE_SOURCE == "merge_request_event"'], changed["rules"].map { |r| r["if"] }
    assert_equal "0", changed.dig("variables", "GIT_DEPTH")
  end

  def test_all_is_manual_on_the_default_branch
    rule = job("PrecommitAll")["rules"].first

    assert_equal "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH", rule["if"]
    assert_equal "manual", rule["when"]
    assert rule["allow_failure"]
  end
end

class TagMintTemplateTest < Minitest::Test
  def test_mints_only_on_the_default_branch
    rule = job("TagMint")["rules"].first

    assert_equal "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH", rule["if"]
    assert_equal "$[[ inputs.changes ]]", rule["changes"]
  end

  def test_remaps_the_tagger_token_and_reads_full_history
    vars = job("TagMint")["variables"]

    assert_equal "$REPO_PROTECTED_VAR_BOT_TAG_TOKEN", vars["TAG_TOKEN"]
    assert_equal "0", vars["GIT_DEPTH"]
  end

  def test_is_never_interrupted
    refute job("TagMint")["interruptible"]
  end
end

class EmitEventsTemplateTest < Minitest::Test
  def body
    spec_and_body("EmitEvents").last.fetch(".emit-events")
  end

  def test_is_a_hidden_job
    spec_and_body("EmitEvents").last.each_key { |name| assert name.start_with?("."), name }
  end

  def test_takes_the_image_input_every_other_template_takes
    assert spec_and_body("EmitEvents").first.dig("spec", "inputs", "image").key?("default")
    assert_equal "$[[ inputs.image ]]", body["image"]
  end

  def test_renders_its_script_rather_than_assuming_a_make_target
    bootstrap = body["script"].first

    refute_includes bootstrap, "make "
    assert_includes bootstrap, "shared/generic/ci/emit-events.zsh"
    assert_includes bootstrap, "--profiles=genericSetup"
  end

  def test_runs_its_script_after_the_bootstrap
    assert_includes body["script"].last, "shared/generic/ci/emit-events.zsh"
  end

  def test_runs_on_every_tag_and_on_declaration_changes_only_on_main
    rules = body["rules"]

    assert_equal "$CI_COMMIT_TAG", rules.first["if"]
    assert_equal %w[.repo/*.tpl .repo/deps-graph.yml .repo/upstream.yml .repo/upstream.env], rules.last["changes"]
  end
end

class BaseTemplateTest < Minitest::Test
  def bodies
    template("CheProfileBase").first
  end

  def test_defines_only_hidden_jobs
    bodies.each_key { |name| assert name.start_with?("."), "#{name} must be a hidden job" }
  end

  def test_both_bodies_run_the_same_make_target
    bodies.each_value { |body| assert_includes body["script"].join(" "), "sync-full" }
  end

  def test_the_as_user_body_hands_every_upstream_pin_to_sudo
    script = bodies.fetch(".che-profile-matrix-true")["script"].join(" ")

    %w[CHE_PROFILE MK_DRY_RUN CHE_PACKAGES_REF CENTRALIZED_ASSETS_GENERIC_REF CENTRALIZED_ASSETS_PROSE_HUMAN_REF
       CENTRALIZED_ASSETS_PROSE_AI_REF CENTRALIZED_ASSETS_PROSE_COMMON_REF PROSE_SPEC_REF TOOLS_CONFIGS_REF
       AUTOMATION_REF].each do |name|
      assert_includes script, name
    end
  end
end
##[<] 🤖🤖
