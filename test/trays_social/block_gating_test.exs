defmodule TraysSocial.BlockGatingTest do
  @moduledoc """
  W166: blocks are enforced at write time — follows, likes, comments, and
  notifications are refused between blocked pairs in either direction.
  Inverts the 2026-07-02 review repro which demonstrated a blocked user
  could re-follow and comment on their blocker.
  """
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.{Accounts, Notifications, Posts, Repo}
  alias TraysSocial.Notifications.Notification

  setup do
    blocker = user_fixture()
    blocked = user_fixture()
    {:ok, _} = Accounts.block_user(blocker.id, blocked.id)
    %{blocker: blocker, blocked: blocked}
  end

  describe "blocked_between?/2" do
    test "true in both directions, false for unrelated users", %{
      blocker: blocker,
      blocked: blocked
    } do
      assert Accounts.blocked_between?(blocker.id, blocked.id)
      assert Accounts.blocked_between?(blocked.id, blocker.id)
      refute Accounts.blocked_between?(blocker.id, user_fixture().id)
    end
  end

  describe "follow_user/2 gating" do
    test "blocked user cannot re-follow the blocker", %{blocker: blocker, blocked: blocked} do
      assert {:error, :blocked} = Accounts.follow_user(blocked, blocker)
    end

    test "blocker cannot follow the blocked user either", %{blocker: blocker, blocked: blocked} do
      assert {:error, :blocked} = Accounts.follow_user(blocker, blocked)
    end

    test "unrelated users still follow normally", %{blocker: blocker} do
      other = user_fixture()
      assert {:ok, _} = Accounts.follow_user(other, blocker)
    end
  end

  describe "like_post/2 and create_comment/3 gating" do
    test "blocked user cannot like or comment on the blocker's post", %{
      blocker: blocker,
      blocked: blocked
    } do
      post = post_fixture(user_id: blocker.id)

      assert {:error, :blocked} = Posts.like_post(post, blocked)
      assert {:error, :blocked} = Posts.create_comment(post, blocked, %{body: "still here"})
    end

    test "blocker cannot interact with the blocked user's post", %{
      blocker: blocker,
      blocked: blocked
    } do
      post = post_fixture(user_id: blocked.id)

      assert {:error, :blocked} = Posts.like_post(post, blocker)
      assert {:error, :blocked} = Posts.create_comment(post, blocker, %{body: "hi"})
    end

    test "own posts and unrelated users are unaffected", %{blocker: blocker} do
      post = post_fixture(user_id: blocker.id)
      other = user_fixture()

      assert {:ok, _} = Posts.like_post(post, other)
      assert {:ok, _} = Posts.create_comment(post, blocker, %{body: "note to self"})
    end
  end

  describe "create_notification/1 gating" do
    test "no notification row between blocked pairs", %{blocker: blocker, blocked: blocked} do
      assert {:ok, :skipped} =
               Notifications.create_notification(%{
                 type: "like",
                 user_id: blocker.id,
                 actor_id: blocked.id
               })

      assert Repo.all(Notification) == []
    end
  end

  describe "read surfaces exclude blocked pairs (W167)" do
    test "blocked_pair_ids/1 returns both directions", %{blocker: blocker, blocked: blocked} do
      third = user_fixture()
      {:ok, _} = Accounts.block_user(third.id, blocker.id)

      assert Enum.sort(Accounts.blocked_pair_ids(blocker.id)) ==
               Enum.sort([blocked.id, third.id])
    end

    test "trending and search exclude blocked users' posts", %{
      blocker: blocker,
      blocked: blocked
    } do
      blocked_post = post_fixture(user_id: blocked.id, caption: "secret pasta")
      visible_post = post_fixture(user_id: user_fixture().id, caption: "public pasta")
      pair_ids = Accounts.blocked_pair_ids(blocker.id)

      trending_ids =
        Posts.list_trending_posts(20, blocked_user_ids: pair_ids) |> Enum.map(& &1.id)

      refute blocked_post.id in trending_ids
      assert visible_post.id in trending_ids

      search_ids =
        Posts.search_posts("pasta", blocked_user_ids: pair_ids) |> Enum.map(& &1.id)

      refute blocked_post.id in search_ids
      assert visible_post.id in search_ids
    end

    test "search_users excludes blocked pairs", %{blocker: blocker, blocked: blocked} do
      pair_ids = Accounts.blocked_pair_ids(blocker.id)
      prefix = String.slice(blocked.username, 0, 8)

      results = Accounts.search_users(prefix, blocked_user_ids: pair_ids)
      refute Enum.any?(results, &(&1.id == blocked.id))
    end

    test "follower listings exclude blocked pairs", %{blocker: blocker, blocked: blocked} do
      target = user_fixture()
      {:ok, _} = Accounts.follow_user(blocked, target)
      {:ok, _} = Accounts.follow_user(blocker, target)

      pair_ids = Accounts.blocked_pair_ids(blocker.id)

      follower_ids =
        Accounts.list_followers(target.id, blocked_user_ids: pair_ids) |> Enum.map(& &1.id)

      refute blocked.id in follower_ids
      assert blocker.id in follower_ids
    end
  end

  describe "unread_count/1 parity with the filtered list" do
    test "excludes notifications from actors the user later blocked", %{blocker: blocker} do
      harasser = user_fixture()

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: blocker.id,
          actor_id: harasser.id
        })

      assert Notifications.unread_count(blocker.id) == 1

      {:ok, _} = Accounts.block_user(blocker.id, harasser.id)

      assert Notifications.unread_count(blocker.id) == 0
    end
  end
end
