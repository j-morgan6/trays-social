defmodule TraysSocial.MutedKeywordsTest do
  @moduledoc """
  D108 regressions: SQL three-valued logic hid every caption-less post the
  moment ANY keyword was muted, and unescaped LIKE metacharacters let a
  keyword containing % mute every captioned post.
  """
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Posts

  test "caption-less posts survive muted-keyword filtering (inverted repro)" do
    user = user_fixture()
    captionless = post_fixture(user_id: user.id, caption: nil)
    muted = post_fixture(user_id: user.id, caption: "cilantro salad")
    visible = post_fixture(user_id: user.id, caption: "plain toast")

    ids = Posts.list_posts(muted_keywords: ["cilantro"]) |> Enum.map(& &1.id)

    assert captionless.id in ids
    assert visible.id in ids
    refute muted.id in ids
  end

  test "LIKE metacharacters in keywords are treated literally" do
    user = user_fixture()
    literal_match = post_fixture(user_id: user.id, caption: "sale: 50% off meal kits")
    innocent = post_fixture(user_id: user.id, caption: "weeknight dinner")

    ids = Posts.list_posts(muted_keywords: ["50% off"]) |> Enum.map(& &1.id)

    refute literal_match.id in ids
    assert innocent.id in ids
  end

  test "matching is case-insensitive" do
    user = user_fixture()
    muted = post_fixture(user_id: user.id, caption: "CILANTRO everywhere")

    ids = Posts.list_posts(muted_keywords: ["cilantro"]) |> Enum.map(& &1.id)

    refute muted.id in ids
  end
end
