defmodule TraysSocial.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TraysSocial.Posts` context.
  """

  @doc """
  Generate a comment.
  """
  def comment_fixture(post, user, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{body: "some comment body"})
    {:ok, comment} = TraysSocial.Posts.create_comment(post, user, attrs)
    comment
  end

  @doc """
  Generate a post.

  Accepts either a keyword list or a map of attributes.
  Requires :user_id. Supports nested :post_tags, :post_photos, etc.
  """
  def post_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    user_id =
      attrs[:user_id] ||
        raise "user_id is required for post_fixture"

    base_attrs = %{
      caption: "some caption",
      cooking_time_minutes: 42,
      photo_url: "/uploads/test_photo.jpg",
      user_id: user_id,
      ingredients: [%{name: "Test ingredient", quantity: "1", unit: "cup"}],
      cooking_steps: [%{description: "Test step", order: 0}]
    }

    merged = Enum.into(attrs, base_attrs)

    {:ok, post} = TraysSocial.Posts.create_post(merged)

    # Preload associations for tests
    TraysSocial.Repo.preload(post, [:user, :post_photos])
  end
end
