defmodule TraysSocial.ReleaseTest do
  use TraysSocial.DataCase, async: true

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocial.Posts.Post
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

    # The API gates posting/commenting behind email confirmation, and
    # demo_*@trays.app can't receive a confirmation link — so the demo
    # accounts must be seeded already-confirmed or an App Reviewer is stuck.
    test "demo users are email-confirmed" do
      assert :ok = Release.do_seed_demo(@password)

      for username <- ~w(demo_alice demo_ben demo_chloe) do
        user = Repo.get_by(User, username: username)
        assert user.confirmed_at, "expected #{username} to be email-confirmed"
      end
    end

    test "demo login works with the seeded password" do
      assert :ok = Release.do_seed_demo(@password)

      assert Accounts.get_user_by_email_and_password("demo_alice@trays.app", @password),
             "expected demo_alice to log in with the seeded password"
    end

    # The DEMO_USER_PASSWORD secret is authoritative: re-running with a new
    # value resets existing demo accounts' passwords (no delete + reseed).
    test "re-seeding resets the demo password to the current value" do
      assert :ok = Release.do_seed_demo(@password)
      new_password = "differentDemoPw_456"
      assert :ok = Release.do_seed_demo(new_password)

      assert Accounts.get_user_by_email_and_password("demo_alice@trays.app", new_password)
      refute Accounts.get_user_by_email_and_password("demo_alice@trays.app", @password)
    end

    # Re-running the seed must refresh a demo post's photo when the seed URL
    # changed (how a broken/wrong image gets fixed on an already-seeded env
    # without a delete + reseed).
    test "re-seeding refreshes a demo post's photo to match the seed data" do
      assert :ok = Release.do_seed_demo(@password)
      alice = Accounts.get_user_by_email("demo_alice@trays.app")
      caption = "Eggs Benedict for two in 30 minutes flat"
      post = Repo.get_by(Post, user_id: alice.id, caption: caption)
      assert post

      # Simulate a stale/broken photo, then re-seed.
      Repo.update!(Ecto.Changeset.change(post, photo_url: "https://example.com/broken.jpg"))
      assert :ok = Release.do_seed_demo(@password)

      refreshed = Repo.get_by(Post, user_id: alice.id, caption: caption)
      refute refreshed.photo_url == "https://example.com/broken.jpg"
      assert refreshed.photo_url =~ "images.unsplash.com"
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
