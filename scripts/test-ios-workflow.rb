# test-ios-workflow.rb — structural checks on .github/workflows/ios.yml.
#
# The Release upload's safety rests on the shape of the workflow, not on any
# code a unit test could call: which events start it, which environment gates
# it, which jobs can reach the App Store Connect key, and that nothing submits
# for App Review. A real dispatch can only be tried after merge, so these
# checks pin that shape in CI and fail when an edit loosens it.
#
# Run: ruby scripts/test-ios-workflow.rb [path/to/ios.yml]

require "yaml"

path = ARGV[0] || File.expand_path("../.github/workflows/ios.yml", __dir__)
wf = YAML.safe_load(File.read(path), aliases: false)
# YAML 1.1 reads a bare `on:` key as the boolean true.
on = wf["on"] || wf[true] || {}
jobs = wf["jobs"] || {}

$failures = []
def check(ok, msg)
  $failures << msg unless ok
end

def env_name(job)
  e = job["environment"]
  e.is_a?(Hash) ? e["name"] : e
end

def runs(job)
  (job["steps"] || []).map { |s| s["run"].to_s }
end

def needs(job)
  Array(job["needs"])
end

# --- The dispatch input ------------------------------------------------------
input = on.dig("workflow_dispatch", "inputs", "release") || {}
check(input["type"] == "boolean", "workflow_dispatch input `release` is not a boolean")
check(input["default"] == false, "workflow_dispatch input `release` does not default to false")

# --- testflight_release: trigger, gate, concurrency -------------------------
rel = jobs["testflight_release"]
check(!rel.nil?, "there is no testflight_release job")
rel ||= {}
cond = rel["if"].to_s
check(needs(rel).include?("test"), "testflight_release does not need test")
check(env_name(rel) == "production", "testflight_release is not in the production environment")
check(cond.include?("github.event_name == 'workflow_dispatch'"), "testflight_release's if does not require workflow_dispatch")
check(cond.include?("github.ref == 'refs/heads/main'"), "testflight_release's if does not require main")
check(cond.include?("inputs.release == true"), "testflight_release's if does not require inputs.release == true")
check(!cond.include?("push"), "testflight_release's if mentions push")
check(!cond.include?("||"), "testflight_release's if has an alternative (||) that could bypass the dispatch-only rule")
conc = rel["concurrency"] || {}
check(conc["group"] == "ios-testflight-release", "testflight_release's concurrency group is not ios-testflight-release")
check(conc["cancel-in-progress"] == false, "testflight_release's concurrency can cancel an in-progress upload")

# --- testflight_release: what it builds and uploads -------------------------
rel_runs = runs(rel)
rel_env = rel["env"] || {}
check(rel_env["BUILD_SUFFIX"].to_s == "1", "testflight_release's BUILD_SUFFIX is not 1")
check(rel_env["EXPECTED_API_BASE_URL"] == "https://trays.app", "testflight_release does not expect the prod backend")
check(rel_runs.any? { |r| r.include?('scripts/regen-xcodeproj.sh "$BUILD_SUFFIX"') },
      "testflight_release does not regenerate with the build suffix")
archive = rel_runs.find { |r| r.include?("xcodebuild archive") } || ""
check(archive =~ /-scheme TraysSocial\s*\\/, "testflight_release does not archive the TraysSocial scheme")
check(archive.include?("-configuration Release"), "testflight_release does not archive the Release configuration")
check(rel_runs.any? { |r| r.include?("-exportArchive") && r.include?("ios/TraysSocial/ExportOptions-AppStore.plist") },
      "testflight_release does not upload with ExportOptions-AppStore.plist")
last = (rel["steps"] || []).last || {}
check(last["if"] == "always()" && last["run"].to_s.include?('rm -rf "$RUNNER_TEMP/asc-key"'),
      "testflight_release's last step is not the always() key removal")

# --- testflight_beta never runs on a release dispatch -----------------------
beta_cond = (jobs["testflight_beta"] || {})["if"].to_s
check(beta_cond.include?("github.ref == 'refs/heads/main'"), "testflight_beta's if does not require main")
check(beta_cond.include?("inputs.release != true"), "testflight_beta's if does not skip a release dispatch")

# --- A rejected approval uploads nothing ------------------------------------
# Only a gated job may touch the key, and only the production-gated job may
# build the Release (prod) app. An ungated archive or upload job in front of
# testflight_release would build or ship prod without an approval.
jobs.each do |name, job|
  text = runs(job).join("\n") + (job["env"] || {}).to_s +
         (job["steps"] || []).map { |s| s["env"].to_s }.join("\n")
  if text.include?("secrets.ASC_")
    check(%w[testflight production].include?(env_name(job)),
          "job #{name} reads an App Store Connect secret outside the testflight/production environments")
  end
  # The test job builds the TraysSocial scheme too, but for the simulator
  # with no signing; only an archive or a suffixed regen is a Release build.
  release_build = runs(job).any? do |r|
    (r.include?("xcodebuild archive") && (r.include?("-configuration Release") || r =~ /-scheme TraysSocial\s*\\/)) ||
      r.include?("regen-xcodeproj.sh \"$BUILD_SUFFIX\"")
  end
  if release_build
    check(env_name(job) == "production", "job #{name} builds the Release app outside the production environment")
  end
  if runs(job).any? { |r| r.include?("-exportArchive") }
    check(%w[testflight production].include?(env_name(job)), "job #{name} uploads outside a gated environment")
  end
end

# --- Nothing submits for App Review -----------------------------------------
submit = /altool|fastlane|\bdeliver\b|submit|reviewSubmission|appStoreVersionSubmission|api\.appstoreconnect\.apple\.com/i
jobs.each do |name, job|
  (job["steps"] || []).each do |s|
    check(!(s["run"].to_s =~ submit) && !(s["uses"].to_s =~ submit),
          "job #{name} step '#{s["name"]}' looks like it submits for review or calls the App Store Connect API")
  end
end

# --- A release dispatch's test run is not cancelled by a push's -------------
test_group = ((jobs["test"] || {})["concurrency"] || {})["group"].to_s
check(test_group.include?("inputs.release"), "the test job's concurrency group is not keyed on the release input")

if $failures.empty?
  puts "ios.yml: all structural checks passed."
else
  $failures.each { |f| warn "FAIL: #{f}" }
  warn "#{$failures.size} check(s) failed."
  exit 1
end
