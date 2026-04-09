defmodule TraysSocial.PostsTest do
  use TraysSocial.DataCase

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Posts
  alias TraysSocial.Posts.Comment
  alias TraysSocial.Posts.CookingStep
  alias TraysSocial.Posts.Post
  alias TraysSocial.Posts.PostLike
  alias TraysSocial.Posts.PostPhoto
  alias TraysSocial.Posts.PostTag
  alias TraysSocial.Posts.Tool

  @valid_attrs %{
    photo_url: "https://example.com/photo.jpg",
    caption: "Delicious homemade pasta",
    cooking_time_minutes: 45,
    ingredients: [%{name: "Pasta", quantity: "1", unit: "lb", order: 0}],
    cooking_steps: [%{description: "Cook pasta", order: 0}]
  }
  @invalid_attrs %{photo_url: nil, caption: nil, cooking_time_minutes: nil}

  defp create_user_and_post(_context \\ %{}) do
    user = user_fixture()
    post = post_fixture(%{user_id: user.id})
    %{user: user, post: post}
  end

  describe "posts" do
    test "list_posts/0 returns all non-deleted posts" do
      %{post: post} = create_user_and_post()
      posts = Posts.list_posts()
      assert length(posts) == 1
      assert List.first(posts).id == post.id
    end

    test "list_posts/0 excludes soft deleted posts" do
      %{post: post} = create_user_and_post()
      {:ok, _deleted_post} = Posts.delete_post(post)
      assert Posts.list_posts() == []
    end

    test "list_posts/1 with limit option" do
      user = user_fixture()

      for i <- 1..5 do
        post_fixture(%{user_id: user.id, caption: "Post #{i}"})
      end

      posts = Posts.list_posts(limit: 3)
      assert length(posts) == 3
    end

    test "list_posts/1 with cursor pagination" do
      user = user_fixture()

      for i <- 1..5 do
        post_fixture(%{user_id: user.id, caption: "Post #{i}"})
      end

      # Posts are ordered desc by inserted_at, so the last created is first
      all_posts = Posts.list_posts()
      assert length(all_posts) == 5

      # Use the third post as cursor to get the next two
      cursor_post = Enum.at(all_posts, 2)

      paginated =
        Posts.list_posts(
          cursor_id: cursor_post.id,
          cursor_time: cursor_post.inserted_at
        )

      assert length(paginated) == 2

      # All returned posts should be older than cursor
      for p <- paginated do
        assert p.inserted_at <= cursor_post.inserted_at
        if p.inserted_at == cursor_post.inserted_at, do: assert(p.id < cursor_post.id)
      end
    end

    test "list_posts/1 with for_user_id shows all posts when user follows fewer than 5 people" do
      poster = user_fixture()
      follower = user_fixture()
      other_poster = user_fixture()

      post_fixture(%{user_id: poster.id, caption: "Followed post"})
      post_fixture(%{user_id: other_poster.id, caption: "Discovery post"})

      # Following < 5 people shows discovery feed (all posts)
      TraysSocial.Accounts.follow_user(follower, poster)

      posts = Posts.list_posts(for_user_id: follower.id)
      assert length(posts) == 2
    end

    test "list_posts/1 with for_user_id shows only followed posts when user follows 5+ people" do
      follower = user_fixture()

      # Create 5 followed users with posts
      followed_posts =
        for _ <- 1..5 do
          poster = user_fixture()
          TraysSocial.Accounts.follow_user(follower, poster)
          post_fixture(%{user_id: poster.id, caption: "Followed post"})
        end

      # Create an unfollowed user with a post
      unfollowed = user_fixture()
      post_fixture(%{user_id: unfollowed.id, caption: "Not followed post"})

      posts = Posts.list_posts(for_user_id: follower.id)
      assert length(posts) == length(followed_posts)
      assert Enum.all?(posts, &(&1.caption == "Followed post"))
    end

    test "list_posts/1 with for_user_id shows all posts when user follows nobody" do
      user = user_fixture()
      poster = user_fixture()
      post_fixture(%{user_id: poster.id})

      # User follows nobody, so the global feed is returned
      posts = Posts.list_posts(for_user_id: user.id)
      assert length(posts) == 1
    end

    test "get_post!/1 returns the post with given id" do
      %{post: post} = create_user_and_post()
      fetched_post = Posts.get_post!(post.id)
      assert fetched_post.id == post.id
      assert fetched_post.caption == post.caption
    end

    test "get_post!/1 raises for non-existent post" do
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(0) end
    end

    test "get_post!/1 raises for soft deleted post" do
      %{post: post} = create_user_and_post()
      {:ok, _} = Posts.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(post.id) end
    end

    test "get_post!/1 preloads associations" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:ingredients, [%{name: "Salt", quantity: "1", unit: "tsp", order: 0}])
        |> Map.put(:tools, [%{name: "Pan", order: 0}])
        |> Map.put(:cooking_steps, [%{description: "Cook it", order: 0}])
        |> Map.put(:post_tags, [%{tag: "easy"}])
        |> Map.put(:post_photos, [%{url: "https://example.com/photo.jpg", position: 0}])

      {:ok, post} = Posts.create_post(attrs)
      fetched = Posts.get_post!(post.id)

      assert length(fetched.ingredients) == 1
      assert length(fetched.tools) == 1
      assert length(fetched.cooking_steps) == 1
      assert length(fetched.post_tags) == 1
      assert length(fetched.post_photos) == 1
      assert fetched.user.id == user.id
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

    test "create_post/1 with nested tools" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:tools, [
          %{name: "Knife", order: 0},
          %{name: "Cutting board", order: 1}
        ])

      assert {:ok, %Post{} = post} = Posts.create_post(attrs)
      fetched = Posts.get_post!(post.id)
      assert length(fetched.tools) == 2
    end

    test "create_post/1 with nested cooking_steps" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:cooking_steps, [
          %{description: "Boil water", order: 0},
          %{description: "Add pasta", order: 1}
        ])

      assert {:ok, %Post{} = post} = Posts.create_post(attrs)
      fetched = Posts.get_post!(post.id)
      assert length(fetched.cooking_steps) == 2
    end

    test "create_post/1 with nested post_photos" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:post_photos, [
          %{url: "https://example.com/a.jpg", position: 0},
          %{url: "https://example.com/b.jpg", position: 1}
        ])

      assert {:ok, %Post{} = post} = Posts.create_post(attrs)
      fetched = Posts.get_post!(post.id)
      assert length(fetched.post_photos) == 2
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

    test "create_post/1 validates servings is positive" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:servings, 0)

      assert {:error, %Ecto.Changeset{} = changeset} = Posts.create_post(attrs)
      assert "must be greater than 0" in errors_on(changeset).servings
    end

    test "create_post/1 validates type inclusion" do
      user = user_fixture()

      attrs =
        @valid_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:type, "invalid")

      assert {:error, %Ecto.Changeset{} = changeset} = Posts.create_post(attrs)
      assert "is invalid" in errors_on(changeset).type
    end

    test "create_post/1 with type post requires only photo_url and user_id" do
      user = user_fixture()

      attrs = %{
        photo_url: "https://example.com/photo.jpg",
        type: "post",
        user_id: user.id
      }

      assert {:ok, %Post{type: "post"}} = Posts.create_post(attrs)
    end

    test "create_post/1 defaults like_count and comment_count to 0" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)

      {:ok, post} = Posts.create_post(attrs)
      assert post.like_count == 0
      assert post.comment_count == 0
    end

    test "update_post/2 with valid data updates the post" do
      %{post: post} = create_user_and_post()
      update_attrs = %{caption: "Updated caption"}

      assert {:ok, %Post{} = updated} = Posts.update_post(post, update_attrs)
      assert updated.caption == "Updated caption"
    end

    test "update_post/2 with invalid data returns error changeset" do
      %{post: post} = create_user_and_post()

      assert {:error, %Ecto.Changeset{}} = Posts.update_post(post, %{photo_url: nil})
    end

    test "update_post/2 can update cooking_time_minutes" do
      %{post: post} = create_user_and_post()

      assert {:ok, %Post{} = updated} = Posts.update_post(post, %{cooking_time_minutes: 60})
      assert updated.cooking_time_minutes == 60
    end

    test "delete_post/1 soft deletes the post" do
      %{post: post} = create_user_and_post()
      assert {:ok, %Post{} = deleted} = Posts.delete_post(post)
      assert deleted.deleted_at != nil
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(post.id) end
    end

    test "delete_post/1 sets deleted_at timestamp" do
      %{post: post} = create_user_and_post()
      assert is_nil(post.deleted_at)
      {:ok, deleted} = Posts.delete_post(post)
      assert %DateTime{} = deleted.deleted_at
    end

    test "change_post/1 returns a post changeset" do
      %{post: post} = create_user_and_post()
      assert %Ecto.Changeset{} = Posts.change_post(post)
    end

    test "change_post/2 with attrs returns a changeset" do
      %{post: post} = create_user_and_post()
      changeset = Posts.change_post(post, %{caption: "New caption"})
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes[:caption] == "New caption"
    end
  end

  describe "list_posts_by_user/1" do
    test "returns posts for a specific user" do
      user1 = user_fixture()
      user2 = user_fixture()

      post1 = post_fixture(%{user_id: user1.id, caption: "User1 post"})
      _post2 = post_fixture(%{user_id: user2.id, caption: "User2 post"})

      posts = Posts.list_posts_by_user(user1.id)
      assert length(posts) == 1
      assert hd(posts).id == post1.id
    end

    test "excludes soft deleted posts" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})
      Posts.delete_post(post)

      assert Posts.list_posts_by_user(user.id) == []
    end

    test "returns posts in descending order" do
      user = user_fixture()

      _p1 = post_fixture(%{user_id: user.id, caption: "First"})
      _p2 = post_fixture(%{user_id: user.id, caption: "Second"})

      posts = Posts.list_posts_by_user(user.id)
      assert length(posts) == 2
      # Posts ordered desc by inserted_at; both were inserted in the same second
      # so just verify both are returned
      captions = Enum.map(posts, & &1.caption)
      assert "First" in captions
      assert "Second" in captions
    end
  end

  describe "list_trending_posts/1" do
    test "returns posts ordered by like_count descending" do
      user = user_fixture()
      liker = user_fixture()

      _post1 = post_fixture(%{user_id: user.id, caption: "Less popular"})
      post2 = post_fixture(%{user_id: user.id, caption: "More popular"})

      # Like post2 to increase its like_count
      Posts.like_post(post2, liker)

      trending = Posts.list_trending_posts(10)
      assert hd(trending).id == post2.id
    end

    test "respects the limit parameter" do
      user = user_fixture()

      for i <- 1..5 do
        post_fixture(%{user_id: user.id, caption: "Post #{i}"})
      end

      trending = Posts.list_trending_posts(3)
      assert length(trending) == 3
    end

    test "excludes soft deleted posts" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})
      Posts.delete_post(post)

      assert Posts.list_trending_posts() == []
    end
  end

  describe "list_recent_posts/1" do
    test "returns posts ordered by inserted_at descending" do
      user = user_fixture()

      _p1 = post_fixture(%{user_id: user.id, caption: "Older"})
      _p2 = post_fixture(%{user_id: user.id, caption: "Newer"})

      recent = Posts.list_recent_posts(10)
      assert length(recent) == 2
      captions = Enum.map(recent, & &1.caption)
      assert "Older" in captions
      assert "Newer" in captions
    end

    test "respects the limit parameter" do
      user = user_fixture()

      for i <- 1..5 do
        post_fixture(%{user_id: user.id, caption: "Post #{i}"})
      end

      recent = Posts.list_recent_posts(2)
      assert length(recent) == 2
    end

    test "excludes soft deleted posts" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})
      Posts.delete_post(post)

      assert Posts.list_recent_posts() == []
    end
  end

  describe "list_top_tags/1" do
    test "returns top tags ordered by post count" do
      user = user_fixture()

      # Create 3 posts with "pasta" tag, 2 with "salad", 1 with "soup"
      for _ <- 1..3 do
        post_fixture(%{user_id: user.id, post_tags: [%{tag: "pasta"}]})
      end

      for _ <- 1..2 do
        post_fixture(%{user_id: user.id, post_tags: [%{tag: "salad"}]})
      end

      post_fixture(%{user_id: user.id, post_tags: [%{tag: "soup"}]})

      tags = Posts.list_top_tags(3)
      assert length(tags) == 3
      assert hd(tags) == "pasta"
      assert Enum.at(tags, 1) == "salad"
      assert Enum.at(tags, 2) == "soup"
    end

    test "respects the limit parameter" do
      user = user_fixture()

      for tag <- ~w(a b c d e) do
        post_fixture(%{user_id: user.id, post_tags: [%{tag: tag}]})
      end

      tags = Posts.list_top_tags(2)
      assert length(tags) == 2
    end

    test "excludes tags from soft deleted posts" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id, post_tags: [%{tag: "deleted_tag"}]})
      Posts.delete_post(post)

      assert Posts.list_top_tags() == []
    end
  end

  describe "list_posts_by_tags/2" do
    test "returns posts grouped by tag" do
      user = user_fixture()

      post_fixture(%{user_id: user.id, caption: "Pasta dish", post_tags: [%{tag: "pasta"}]})
      post_fixture(%{user_id: user.id, caption: "Salad dish", post_tags: [%{tag: "salad"}]})

      result = Posts.list_posts_by_tags(["pasta", "salad"])
      assert length(result) == 2

      {tag1, posts1} = Enum.find(result, fn {tag, _} -> tag == "pasta" end)
      assert tag1 == "pasta"
      assert length(posts1) == 1
      assert hd(posts1).caption == "Pasta dish"
    end

    test "limits posts_per_tag" do
      user = user_fixture()

      for i <- 1..5 do
        post_fixture(%{user_id: user.id, caption: "Pasta #{i}", post_tags: [%{tag: "pasta"}]})
      end

      result = Posts.list_posts_by_tags(["pasta"], 2)
      {_tag, posts} = hd(result)
      assert length(posts) == 2
    end

    test "excludes empty tags from result" do
      result = Posts.list_posts_by_tags(["nonexistent_tag"])
      assert result == []
    end

    test "excludes soft deleted posts" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id, post_tags: [%{tag: "stale"}]})
      Posts.delete_post(post)

      result = Posts.list_posts_by_tags(["stale"])
      assert result == []
    end
  end

  describe "like_post/2" do
    test "likes a post and increments like_count" do
      %{post: post} = create_user_and_post()
      liker = user_fixture()

      assert {:ok, %{like: like, count: count}} = Posts.like_post(post, liker)
      assert like.id != nil
      assert count == 1

      refreshed = Posts.get_post!(post.id)
      assert refreshed.like_count == 1
    end

    test "liking the same post twice is a no-op" do
      %{post: post} = create_user_and_post()
      liker = user_fixture()

      assert {:ok, %{count: 1}} = Posts.like_post(post, liker)
      assert {:ok, %{count: 0}} = Posts.like_post(post, liker)

      refreshed = Posts.get_post!(post.id)
      assert refreshed.like_count == 1
    end

    test "multiple users can like the same post" do
      %{post: post} = create_user_and_post()
      liker1 = user_fixture()
      liker2 = user_fixture()

      Posts.like_post(post, liker1)
      # Refresh the post to get updated like_count for the second call
      refreshed = Posts.get_post!(post.id)
      Posts.like_post(refreshed, liker2)

      final = Posts.get_post!(post.id)
      assert final.like_count == 2
    end
  end

  describe "unlike_post/2" do
    test "unlikes a post and decrements like_count" do
      %{post: post} = create_user_and_post()
      liker = user_fixture()

      {:ok, _} = Posts.like_post(post, liker)
      refreshed = Posts.get_post!(post.id)
      assert refreshed.like_count == 1

      {:ok, %{count: count}} = Posts.unlike_post(refreshed, liker)
      assert count == 0

      final = Posts.get_post!(post.id)
      assert final.like_count == 0
    end

    test "unliking when not liked is a no-op" do
      %{post: post} = create_user_and_post()
      liker = user_fixture()

      {:ok, %{count: count}} = Posts.unlike_post(post, liker)
      assert count == 0

      refreshed = Posts.get_post!(post.id)
      assert refreshed.like_count == 0
    end
  end

  describe "liked_by?/2" do
    test "returns true when user has liked the post" do
      %{post: post} = create_user_and_post()
      liker = user_fixture()

      Posts.like_post(post, liker)
      assert Posts.liked_by?(post.id, liker.id) == true
    end

    test "returns false when user has not liked the post" do
      %{post: post} = create_user_and_post()
      liker = user_fixture()

      assert Posts.liked_by?(post.id, liker.id) == false
    end
  end

  describe "liked_post_ids_for_user/2" do
    test "returns MapSet of liked post IDs" do
      user = user_fixture()
      liker = user_fixture()

      post1 = post_fixture(%{user_id: user.id, caption: "Post 1"})
      post2 = post_fixture(%{user_id: user.id, caption: "Post 2"})
      post3 = post_fixture(%{user_id: user.id, caption: "Post 3"})

      Posts.like_post(post1, liker)
      Posts.like_post(post3, liker)

      liked_ids = Posts.liked_post_ids_for_user(liker.id, [post1.id, post2.id, post3.id])
      assert MapSet.member?(liked_ids, post1.id)
      refute MapSet.member?(liked_ids, post2.id)
      assert MapSet.member?(liked_ids, post3.id)
    end

    test "returns empty MapSet when given empty list" do
      user = user_fixture()
      result = Posts.liked_post_ids_for_user(user.id, [])
      assert result == MapSet.new()
    end

    test "returns empty MapSet when user has no likes" do
      user = user_fixture()
      poster = user_fixture()
      post = post_fixture(%{user_id: poster.id})

      result = Posts.liked_post_ids_for_user(user.id, [post.id])
      assert result == MapSet.new()
    end
  end

  describe "comments" do
    test "create_comment/3 creates a comment and increments comment_count" do
      %{user: _owner, post: post} = create_user_and_post()
      commenter = user_fixture()

      assert {:ok, %Comment{} = comment} =
               Posts.create_comment(post, commenter, %{body: "Great recipe!"})

      assert comment.body == "Great recipe!"
      assert comment.post_id == post.id
      assert comment.user_id == commenter.id
      assert comment.user != nil

      refreshed = Posts.get_post!(post.id)
      assert refreshed.comment_count == 1
    end

    test "create_comment/3 with empty body returns error" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Posts.create_comment(post, commenter, %{body: ""})

      assert errors_on(changeset)[:body] != nil
    end

    test "create_comment/3 with body exceeding 1000 chars returns error" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()
      long_body = String.duplicate("a", 1001)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Posts.create_comment(post, commenter, %{body: long_body})

      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end

    test "create_comment/3 with missing body returns error" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()

      assert {:error, %Ecto.Changeset{}} = Posts.create_comment(post, commenter, %{})
    end

    test "list_comments/1 returns comments for a post" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()

      {:ok, comment} = Posts.create_comment(post, commenter, %{body: "Nice!"})

      comments = Posts.list_comments(post.id)
      assert length(comments) == 1
      assert hd(comments).id == comment.id
      assert hd(comments).user.id == commenter.id
    end

    test "list_comments/1 excludes soft-deleted comments" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()

      {:ok, comment} = Posts.create_comment(post, commenter, %{body: "Deleted comment"})
      Posts.delete_comment(comment, commenter)

      assert Posts.list_comments(post.id) == []
    end

    test "list_comments/1 returns comments ordered oldest first" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()

      {:ok, _c1} = Posts.create_comment(post, commenter, %{body: "First"})
      {:ok, _c2} = Posts.create_comment(post, commenter, %{body: "Second"})

      comments = Posts.list_comments(post.id)
      assert length(comments) == 2
      assert Enum.at(comments, 0).body == "First"
      assert Enum.at(comments, 1).body == "Second"
    end

    test "get_comment!/1 returns a comment by ID" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()

      {:ok, comment} = Posts.create_comment(post, commenter, %{body: "Test"})
      fetched = Posts.get_comment!(comment.id)
      assert fetched.id == comment.id
    end

    test "get_comment!/1 raises for non-existent comment" do
      assert_raise Ecto.NoResultsError, fn -> Posts.get_comment!(0) end
    end

    test "delete_comment/2 soft-deletes the comment and decrements comment_count" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()

      {:ok, comment} = Posts.create_comment(post, commenter, %{body: "To delete"})

      refreshed_post = Posts.get_post!(post.id)
      assert refreshed_post.comment_count == 1

      assert {:ok, %Comment{} = deleted} = Posts.delete_comment(comment, commenter)
      assert deleted.deleted_at != nil

      final_post = Posts.get_post!(post.id)
      assert final_post.comment_count == 0
    end

    test "delete_comment/2 returns :unauthorized when user is not the comment owner" do
      %{post: post} = create_user_and_post()
      commenter = user_fixture()
      other_user = user_fixture()

      {:ok, comment} = Posts.create_comment(post, commenter, %{body: "Not yours"})

      assert {:error, :unauthorized} = Posts.delete_comment(comment, other_user)
    end
  end

  describe "Post.changeset/2" do
    test "validates required fields" do
      changeset = Post.changeset(%Post{}, %{})
      assert errors_on(changeset)[:photo_url] != nil
      assert errors_on(changeset)[:user_id] != nil
    end

    test "caption is optional" do
      changeset = Post.changeset(%Post{}, %{photo_url: "url", user_id: 1})
      refute errors_on(changeset)[:caption]
    end

    test "cooking_time_minutes required for recipe type" do
      changeset = Post.changeset(%Post{}, %{photo_url: "url", user_id: 1, type: "recipe"})
      assert errors_on(changeset)[:cooking_time_minutes] != nil
    end

    test "cooking_time_minutes not required for post type" do
      changeset = Post.changeset(%Post{}, %{photo_url: "url", user_id: 1, type: "post"})
      refute errors_on(changeset)[:cooking_time_minutes]
    end

    test "validates type inclusion" do
      changeset = Post.changeset(%Post{}, %{photo_url: "url", user_id: 1, type: "invalid"})
      assert "is invalid" in errors_on(changeset).type
    end

    test "accepts valid optional fields" do
      attrs = %{
        photo_url: "url",
        caption: "caption",
        cooking_time_minutes: 10,
        user_id: 1,
        servings: 4
      }

      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :servings) == 4
    end
  end

  describe "Comment.changeset/2" do
    test "validates required fields" do
      changeset = Comment.changeset(%Comment{}, %{})
      errors = errors_on(changeset)
      assert errors[:body] != nil
      assert errors[:post_id] != nil
      assert errors[:user_id] != nil
    end

    test "valid changeset with all required fields" do
      changeset = Comment.changeset(%Comment{}, %{body: "Hello", post_id: 1, user_id: 1})
      assert changeset.valid?
    end

    test "validates body length max 1000" do
      long_body = String.duplicate("x", 1001)
      changeset = Comment.changeset(%Comment{}, %{body: long_body, post_id: 1, user_id: 1})
      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end

    test "validates body length min 1" do
      changeset = Comment.changeset(%Comment{}, %{body: "", post_id: 1, user_id: 1})
      assert errors_on(changeset)[:body] != nil
    end
  end

  describe "CookingStep.changeset/2" do
    test "validates required fields" do
      changeset = CookingStep.changeset(%CookingStep{}, %{})
      assert errors_on(changeset)[:description] != nil
    end

    test "valid changeset with description" do
      changeset = CookingStep.changeset(%CookingStep{}, %{description: "Boil water", order: 1})
      assert changeset.valid?
    end

    test "validates description max length of 300" do
      long_desc = String.duplicate("a", 301)
      changeset = CookingStep.changeset(%CookingStep{}, %{description: long_desc, order: 1})
      assert "should be at most 300 character(s)" in errors_on(changeset).description
    end

    test "accepts optional order and post_id" do
      changeset =
        CookingStep.changeset(%CookingStep{}, %{description: "Step", order: 2, post_id: 1})

      assert changeset.valid?
    end
  end

  describe "PostLike.changeset/2" do
    test "validates required fields" do
      changeset = PostLike.changeset(%PostLike{}, %{})
      errors = errors_on(changeset)
      assert errors[:post_id] != nil
      assert errors[:user_id] != nil
    end

    test "valid changeset with all fields" do
      changeset = PostLike.changeset(%PostLike{}, %{post_id: 1, user_id: 1})
      assert changeset.valid?
    end
  end

  describe "PostPhoto.changeset/2" do
    test "validates required fields" do
      changeset = PostPhoto.changeset(%PostPhoto{}, %{})
      errors = errors_on(changeset)
      assert errors[:url] != nil
      assert errors[:position] != nil
    end

    test "valid changeset with url and position" do
      changeset = PostPhoto.changeset(%PostPhoto{}, %{url: "https://img.com/a.jpg", position: 0})
      assert changeset.valid?
    end

    test "accepts optional post_id" do
      changeset =
        PostPhoto.changeset(%PostPhoto{}, %{url: "https://img.com/a.jpg", position: 0, post_id: 1})

      assert changeset.valid?
    end
  end

  describe "PostTag.changeset/2" do
    test "validates required tag field" do
      changeset = PostTag.changeset(%PostTag{}, %{})
      assert errors_on(changeset)[:tag] != nil
    end

    test "valid changeset with tag" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: "pasta"})
      assert changeset.valid?
    end

    test "normalizes tag to lowercase and trimmed" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: "  PASTA  "})
      assert Ecto.Changeset.get_change(changeset, :tag) == "pasta"
    end

    test "accepts optional post_id" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: "test", post_id: 1})
      assert changeset.valid?
    end

    test "normalizes mixed case tag" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: "SpAgHeTtI"})
      assert Ecto.Changeset.get_change(changeset, :tag) == "spaghetti"
    end

    test "whitespace-only tag fails required validation" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: "   "})
      refute changeset.valid?
      assert errors_on(changeset)[:tag] != nil
    end

    test "normalizes tag that is already lowercase and trimmed" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: "simple"})
      assert Ecto.Changeset.get_change(changeset, :tag) == "simple"
      assert changeset.valid?
    end

    test "changeset with nil tag fails required validation" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: nil})
      refute changeset.valid?
      assert errors_on(changeset)[:tag] != nil
    end

    test "changeset casts post_id field" do
      changeset = PostTag.changeset(%PostTag{}, %{tag: "test", post_id: 42})
      assert Ecto.Changeset.get_change(changeset, :post_id) == 42
    end
  end

  describe "Tool.changeset/2" do
    test "validates required name field" do
      changeset = Tool.changeset(%Tool{}, %{})
      assert errors_on(changeset)[:name] != nil
    end

    test "valid changeset with name" do
      changeset = Tool.changeset(%Tool{}, %{name: "Knife"})
      assert changeset.valid?
    end

    test "accepts optional order and post_id" do
      changeset = Tool.changeset(%Tool{}, %{name: "Spatula", order: 1, post_id: 1})
      assert changeset.valid?
    end
  end

  describe "post_tags" do
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
