defmodule TraysSocial.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TraysSocial.Posts` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    user_id =
      attrs[:user_id] ||
        raise "user_id is required for post_fixture"

    {:ok, post} =
      attrs
      |> Enum.into(%{
        caption: "some caption",
        cooking_time_minutes: 42,
        photo_url: "/uploads/test_photo.jpg",
        user_id: user_id
      })
      |> TraysSocial.Posts.create_post()

    # Preload user association for tests
    TraysSocial.Repo.preload(post, :user)
  end
end
