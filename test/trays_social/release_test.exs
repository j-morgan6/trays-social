defmodule TraysSocial.ReleaseTest do
  use TraysSocial.DataCase, async: true

  alias TraysSocial.Accounts.User
  alias TraysSocial.Release

  # 12+ chars so register_user's password validation passes (matches the
  # DEMO_USER_PASSWORD minimum enforced by seed_demo/0).
  @password "demoSeedTestPw_123"

  describe "do_seed_demo/1" do
    test "creates the three demo accounts" do
      assert :ok = Release.do_seed_demo(@password)

      for username <- ~w(demo_alice demo_ben demo_chloe) do
        assert Repo.get_by(User, username: username),
               "expected demo user #{username} to be seeded"
      end
    end

    # Regression for the prod failure on 2026-05-29: register_user requires
    # the virtual `age_confirmation` field (validate_required +
    # validate_acceptance), so the seeder must pass `age_confirmation: true`.
    # Without it the very first upsert_demo_user/4 raised a MatchError.
    test "demo users pass the age_confirmation acceptance validation" do
      assert :ok = Release.do_seed_demo(@password)

      alice = Repo.get_by(User, username: "demo_alice")
      assert alice
      # Seeded users are confirmed registrations — the changeset would have
      # rejected them outright if age_confirmation were missing/false.
      assert alice.hashed_password
    end

    test "is idempotent — re-running creates no duplicate users" do
      assert :ok = Release.do_seed_demo(@password)
      first = Repo.aggregate(User, :count)

      assert :ok = Release.do_seed_demo(@password)
      second = Repo.aggregate(User, :count)

      assert first == 3
      assert second == 3
    end
  end
end
