defmodule TraysSocial.PostsTest do
  use TraysSocial.DataCase

  alias TraysSocial.Posts

  import TraysSocial.AccountsFixtures

  describe "posts" do
    alias TraysSocial.Posts.Post

    @valid_attrs %{
      photo_url: "https://example.com/photo.jpg",
      caption: "Delicious homemade pasta",
      cooking_time_minutes: 45
    }
    @invalid_attrs %{photo_url: nil, caption: nil, cooking_time_minutes: nil}

    def post_fixture(attrs \\ %{}) do
      user = user_fixture()

      {:ok, post} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Map.put(:user_id, user.id)
        |> Posts.create_post()

      post
    end

    test "list_posts/0 returns all non-deleted posts" do
      post = post_fixture()
      posts = Posts.list_posts()
      assert length(posts) == 1
      assert List.first(posts).id == post.id
    end

    test "list_posts/0 excludes soft deleted posts" do
      post = post_fixture()
      {:ok, _deleted_post} = Posts.delete_post(post)
      assert Posts.list_posts() == []
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      fetched_post = Posts.get_post!(post.id)
      assert fetched_post.id == post.id
      assert fetched_post.caption == post.caption
    end

    test "create_post/1 with valid data creates a post" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)

      assert {:ok, %Post{} = post} = Posts.create_post(attrs)
      assert post.photo_url == "https://example.com/photo.jpg"
      assert post.caption == "Delicious homemade pasta"
      assert post.cooking_time_minutes == 45
    end

    test "create_post/1 with nested ingredients creates post with ingredients" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:ingredients, [
          %{name: "Pasta", quantity: "1", unit: "lb", order: 0},
          %{name: "Tomato Sauce", quantity: "2", unit: "cups", order: 1}
        ])

      assert {:ok, %Post{} = post} = Posts.create_post(attrs)
      post_with_ingredients = Posts.get_post!(post.id)
      assert length(post_with_ingredients.ingredients) == 2
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Posts.create_post(@invalid_attrs)
    end

    test "create_post/1 validates caption length" do
      user = user_fixture()
      long_caption = String.duplicate("a", 501)

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:caption, long_caption)

      assert {:error, %Ecto.Changeset{} = changeset} = Posts.create_post(attrs)
      assert "should be at most 500 character(s)" in errors_on(changeset).caption
    end

    test "create_post/1 validates cooking_time_minutes is positive" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:cooking_time_minutes, -5)

      assert {:error, %Ecto.Changeset{} = changeset} = Posts.create_post(attrs)
      assert "must be greater than 0" in errors_on(changeset).cooking_time_minutes
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{caption: "Updated caption"}

      assert {:ok, %Post{} = post} = Posts.update_post(post, update_attrs)
      assert post.caption == "Updated caption"
    end

    test "delete_post/1 soft deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Posts.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Posts.change_post(post)
    end
  end

  describe "post_tags" do
    alias TraysSocial.Posts.Post

    test "create_post/1 normalizes tags to lowercase" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:post_tags, [
          %{tag: "CHICKEN"},
          %{tag: "  Italian  "}
        ])

      assert {:ok, %Post{} = post} = Posts.create_post(attrs)
      post_with_tags = Posts.get_post!(post.id)
      tags = Enum.map(post_with_tags.post_tags, & &1.tag)
      assert "chicken" in tags
      assert "italian" in tags
    end
  end
end
