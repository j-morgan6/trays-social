defmodule TraysSocial.SearchPostsTest do
  @moduledoc """
  D107 regressions: query+tag combination (double-distinct crash), tag
  ordering (oldest-first via distinct's implicit ORDER BY prefix), keyset
  cursor pagination, and duplicate rows from multi-association matches.
  """
  use TraysSocial.DataCase, async: true

  import Ecto.Query
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.{Posts, Repo}
  alias TraysSocial.Posts.Post

  defp tagged_post(user, caption, tag, minutes_ago) do
    post = post_fixture(user_id: user.id, caption: caption, post_tags: [%{tag: tag}])
    stamp = DateTime.utc_now(:second) |> DateTime.add(-minutes_ago * 60)

    from(p in Post, where: p.id == ^post.id)
    |> Repo.update_all(set: [inserted_at: stamp])

    post
  end

  test "query and tag combined no longer raises (double-distinct regression)" do
    user = user_fixture()
    match = tagged_post(user, "pasta primavera", "dinner", 1)
    _wrong_tag = tagged_post(user, "pasta bake", "lunch", 2)

    ids = Posts.search_posts("pasta", tag: "dinner") |> Enum.map(& &1.id)

    assert ids == [match.id]
  end

  test "tag search returns newest first" do
    user = user_fixture()
    oldest = tagged_post(user, "first", "dinner", 30)
    middle = tagged_post(user, "second", "dinner", 20)
    newest = tagged_post(user, "third", "dinner", 10)

    ids = Posts.search_posts("", tag: "dinner") |> Enum.map(& &1.id)

    assert ids == [newest.id, middle.id, oldest.id]
  end

  test "cursor pagination returns non-overlapping stable pages" do
    user = user_fixture()
    posts = for n <- 1..5, do: tagged_post(user, "soup #{n}", "dinner", 60 - n)
    expected_ids = posts |> Enum.reverse() |> Enum.map(& &1.id)

    page1 = Posts.search_posts("soup", limit: 2)
    assert Enum.map(page1, & &1.id) == Enum.take(expected_ids, 2)

    last = List.last(page1)

    page2 =
      Posts.search_posts("soup", limit: 2, cursor_id: last.id, cursor_time: last.inserted_at)

    assert Enum.map(page2, & &1.id) == expected_ids |> Enum.drop(2) |> Enum.take(2)
  end

  test "a post matching caption AND ingredient AND tag appears exactly once" do
    user = user_fixture()

    post =
      post_fixture(
        user_id: user.id,
        caption: "lemon tart",
        ingredients: [%{name: "lemon zest", quantity: "1", unit: "tbsp"}],
        post_tags: [%{tag: "lemon"}]
      )

    ids = Posts.search_posts("lemon") |> Enum.map(& &1.id)

    assert ids == [post.id]
  end
end
