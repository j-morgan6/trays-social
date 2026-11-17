defmodule TraysSocial.ReleaseTest do
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures, only: [user_fixture: 1]
  import TraysSocial.PostsFixtures, only: [post_fixture: 1]

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.Follow
  alias TraysSocial.Accounts.User
  alias TraysSocial.Home
  alias TraysSocial.Notifications.Notification
  alias TraysSocial.Posts.Bookmark
  alias TraysSocial.Posts.Comment
  alias TraysSocial.Posts.Post
  alias TraysSocial.Posts.PostLike
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
      post |> Ecto.Changeset.change(photo_url: "https://example.com/broken.jpg") |> Repo.update!()
      assert :ok = Release.do_seed_demo(@password)

      refreshed = Repo.get_by(Post, user_id: alice.id, caption: caption)
      refute refreshed.photo_url == "https://example.com/broken.jpg"
      assert refreshed.photo_url =~ "images.unsplash.com"
    end

    # W217: Home's "New from people you follow" has a 7-day window, so a
    # seed older than a week left the reviewer's Home half empty.
    test "re-seeding re-dates the demo posts so demo_alice's Home is populated" do
      assert :ok = Release.do_seed_demo(@password)
      alice = Accounts.get_user_by_email("demo_alice@trays.app")
      stale = DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second)
      Repo.update_all(Post, set: [inserted_at: stale])

      assert Home.build(alice).new_from_following == []

      assert :ok = Release.do_seed_demo(@password)
      home = Home.build(alice)

      assert length(home.new_from_following) == 10

      assert home.new_from_following |> Enum.map(& &1.user.username) |> Enum.uniq() |> Enum.sort() ==
               ["demo_ben", "demo_chloe"]

      assert home.friends_trays |> Enum.map(& &1.user.username) |> Enum.sort() ==
               ["demo_ben", "demo_chloe"]

      assert home.jump_back_in != []
    end

    test "re-seeding never re-dates a post that is not in the seed" do
      assert :ok = Release.do_seed_demo(@password)
      alice = Accounts.get_user_by_email("demo_alice@trays.app")
      own = post_fixture(%{user_id: alice.id})
      stale = DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second)
      own |> Ecto.Changeset.change(inserted_at: stale) |> Repo.update!()

      assert :ok = Release.do_seed_demo(@password)

      assert Repo.get!(Post, own.id).inserted_at == stale
    end

    test "demo_alice saves one recipe from each friend, once" do
      assert :ok = Release.do_seed_demo(@password)
      assert :ok = Release.do_seed_demo(@password)
      alice = Accounts.get_user_by_email("demo_alice@trays.app")

      authors =
        from(b in Bookmark,
          join: p in Post,
          on: p.id == b.post_id,
          join: u in User,
          on: u.id == p.user_id,
          where: b.user_id == ^alice.id,
          select: u.username
        )
        |> Repo.all()
        |> Enum.sort()

      assert authors == ["demo_ben", "demo_chloe"]
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

  describe "do_purge_demo/0" do
    setup do
      assert :ok = Release.do_seed_demo(@password)
      :ok
    end

    test "deletes every demo post and its cascaded likes and comments" do
      # Seed created 15 posts, 12 cross-likes, 6 cross-comments.
      assert Repo.aggregate(Post, :count) == 15
      assert Repo.aggregate(PostLike, :count) == 12
      assert Repo.aggregate(Comment, :count) == 6

      assert :ok = Release.do_purge_demo()

      assert Repo.aggregate(Post, :count) == 0
      assert Repo.aggregate(PostLike, :count) == 0
      assert Repo.aggregate(Comment, :count) == 0
    end

    test "removes the mutual follows and the demo notifications" do
      assert Repo.aggregate(Follow, :count) == 6
      assert Repo.aggregate(Notification, :count) > 0

      assert :ok = Release.do_purge_demo()

      assert Repo.aggregate(Follow, :count) == 0
      assert Repo.aggregate(Notification, :count) == 0
    end

    # The whole point: the accounts must survive so an App Reviewer can still
    # log in to evaluate future submissions (Guideline 2.1).
    test "keeps the three demo accounts confirmed and able to log in" do
      assert :ok = Release.do_purge_demo()

      for username <- ~w(demo_alice demo_ben demo_chloe) do
        user = Repo.get_by(User, username: username)
        assert user, "expected demo user #{username} to survive the purge"
        assert user.confirmed_at, "expected #{username} to stay email-confirmed"
      end

      assert Accounts.get_user_by_email_and_password("demo_alice@trays.app", @password),
             "expected demo_alice to still log in after the purge"
    end

    # A real user's own account and posts must be untouched; only their
    # relationships TO the demo content (a follow of / like on a demo cook)
    # go away with that content.
    test "does not delete a real user's account or their own posts" do
      real = user_fixture(%{username: "real_cook"})
      real_post = post_fixture(%{user_id: real.id, caption: "My real recipe"})

      demo_alice = Accounts.get_user_by_email("demo_alice@trays.app")
      {:ok, _} = Accounts.follow_user(real, demo_alice)

      assert :ok = Release.do_purge_demo()

      assert Repo.get(User, real.id), "real user must survive the purge"
      assert Repo.get(Post, real_post.id), "real user's own post must survive"
      assert Repo.aggregate(Post, :count) == 1
    end

    test "is idempotent — running again on already-purged data is a no-op" do
      assert :ok = Release.do_purge_demo()
      assert :ok = Release.do_purge_demo()

      assert Repo.aggregate(Post, :count) == 0
      assert Repo.aggregate(User, :count) == 3
    end
  end
end
