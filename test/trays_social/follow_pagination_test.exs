defmodule TraysSocial.FollowPaginationTest do
  @moduledoc """
  D109 regressions: the followers/following cursor filtered on the joined
  user's id while ordering by the follow row's inserted_at — uncorrelated
  dimensions, so pages skipped and repeated users (empirically confirmed).
  Keyset is now (follow.inserted_at, follow.id), matching the ORDER BY.
  """
  use TraysSocial.DataCase, async: true

  import Ecto.Query
  import TraysSocial.AccountsFixtures

  alias TraysSocial.{Accounts, Repo}
  alias TraysSocial.Accounts.Follow

  defp stagger_follow(follower_id, followed_id, minutes_ago) do
    stamp = DateTime.utc_now(:second) |> DateTime.add(-minutes_ago * 60)

    from(f in Follow, where: f.follower_id == ^follower_id and f.followed_id == ^followed_id)
    |> Repo.update_all(set: [inserted_at: stamp])
  end

  test "followers paginate with no repeats or skips (inverted review repro)" do
    target = user_fixture()
    u1 = user_fixture()
    u2 = user_fixture()
    u3 = user_fixture()

    # Follow-recency order (newest first): u1, u3, u2 — while ids are
    # u1 < u2 < u3. The old user-id cursor repeated u1 on page 2 here.
    {:ok, _} = Accounts.follow_user(u2, target)
    {:ok, _} = Accounts.follow_user(u3, target)
    {:ok, _} = Accounts.follow_user(u1, target)
    stagger_follow(u2.id, target.id, 3)
    stagger_follow(u3.id, target.id, 2)
    stagger_follow(u1.id, target.id, 1)

    page1 = Accounts.list_followers(target.id, limit: 2)
    assert Enum.map(page1, & &1.user.id) == [u1.id, u3.id]

    last = List.last(page1)

    page2 =
      Accounts.list_followers(target.id, limit: 2, cursor: {last.followed_at, last.follow_id})

    assert Enum.map(page2, & &1.user.id) == [u2.id]
  end

  test "same-second follows paginate deterministically via the id tie-break" do
    target = user_fixture()
    followers = for _ <- 1..4, do: user_fixture()
    for f <- followers, do: {:ok, _} = Accounts.follow_user(f, target)
    # All follows share one inserted_at second; ordering falls to follow.id.

    page1 = Accounts.list_followers(target.id, limit: 2)
    last = List.last(page1)

    page2 =
      Accounts.list_followers(target.id, limit: 2, cursor: {last.followed_at, last.follow_id})

    all_ids = Enum.map(page1 ++ page2, & &1.user.id)
    assert length(all_ids) == 4
    assert Enum.uniq(all_ids) == all_ids
  end

  test "following listing paginates on the follow row too" do
    viewer = user_fixture()
    targets = for _ <- 1..3, do: user_fixture()
    for t <- targets, do: {:ok, _} = Accounts.follow_user(viewer, t)

    page1 = Accounts.list_following(viewer.id, limit: 2)
    last = List.last(page1)

    page2 =
      Accounts.list_following(viewer.id, limit: 2, cursor: {last.followed_at, last.follow_id})

    all_ids = Enum.map(page1 ++ page2, & &1.user.id)
    assert length(all_ids) == 3
    assert Enum.uniq(all_ids) == all_ids
  end

  test "following_ids_among matches per-row following? checks" do
    viewer = user_fixture()
    followed = user_fixture()
    not_followed = user_fixture()
    {:ok, _} = Accounts.follow_user(viewer, followed)

    result = Accounts.following_ids_among(viewer.id, [followed.id, not_followed.id])

    assert result == MapSet.new([followed.id])
    assert Accounts.following_ids_among(viewer.id, []) == MapSet.new()
  end
end
