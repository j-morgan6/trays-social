defmodule TraysSocialWeb.API.V1.SearchGroupedTest do
  # async: false: tests here toggle the global :in_app_ads flag.
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.Follow
  alias TraysSocial.Posts
  alias TraysSocial.Repo

  setup :register_and_api_authenticate_user

  setup do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    %{original: original}
  end

  defp enable_in_app_ads(original) do
    Application.put_env(:trays_social, :features, Keyword.put(original, :in_app_ads, true))
  end

  describe "GET /api/v1/search without grouped or group" do
    test "legacy response shape is unchanged without grouped", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id, caption: "pasta"})
      body = conn |> get("/api/v1/search?q=pasta") |> json_response(200)
      assert body |> Map.keys() |> Enum.sort() == ["cursor", "data"]
      assert Map.keys(body["data"]) |> Enum.sort() == ["posts", "users"]
      refute Map.has_key?(body, "ad_config")
    end

    test "an unknown group value falls back to the legacy shape", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id, caption: "pasta"})
      body = conn |> get("/api/v1/search?group=bogus&q=pasta") |> json_response(200)
      assert Map.keys(body["data"]) |> Enum.sort() == ["posts", "users"]
      refute Map.has_key?(body, "ad_config")
    end
  end

  describe "GET /api/v1/search?grouped=true" do
    test "grouped returns tray, following, everyone", %{conn: conn, user: user} do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(user, friend)
      mine = post_fixture(%{user_id: user.id, caption: "fish taco"})
      theirs = post_fixture(%{user_id: friend.id, caption: "birria taco"})
      other = post_fixture(%{user_id: user_fixture().id, caption: "taco salad"})

      body = conn |> get("/api/v1/search?grouped=true&q=taco") |> json_response(200)
      data = body["data"]

      assert Enum.map(data["tray"], & &1["id"]) == [mine.id]
      assert Enum.map(data["following"], & &1["id"]) == [theirs.id]
      assert [%{"type" => "post", "post" => %{"id" => other_id}}] = data["everyone"]
      assert other_id == other.id
      assert is_list(data["users"])
      assert Map.has_key?(body, "cursor")
      assert %{"enabled" => false} = body["ad_config"]
    end

    test "blocked authors never appear in any group, in either direction", %{
      conn: conn,
      user: user
    } do
      saved_author = user_fixture(%{username: "tacoblocked"})
      saved = post_fixture(%{user_id: saved_author.id, caption: "taco"})
      {:ok, _} = Posts.create_bookmark(user.id, saved.id)
      Accounts.block_user(user.id, saved_author.id)

      # block_user/2 deletes follows both ways; write one back so the
      # following group is exercised against a blocked author too.
      followed = user_fixture()
      post_fixture(%{user_id: followed.id, caption: "taco"})
      Accounts.block_user(user.id, followed.id)
      Repo.insert!(%Follow{follower_id: user.id, followed_id: followed.id})

      blocker = user_fixture()
      post_fixture(%{user_id: blocker.id, caption: "taco"})
      Accounts.block_user(blocker.id, user.id)

      data =
        conn
        |> get("/api/v1/search?grouped=true&q=taco")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["tray"] == []
      assert data["following"] == []
      assert data["everyone"] == []
      refute Enum.any?(data["users"], &(&1["id"] == saved_author.id))
    end

    test "a bookmarked friend recipe appears only in tray", %{conn: conn, user: user} do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(user, friend)
      saved = post_fixture(%{user_id: friend.id, caption: "taco"})
      {:ok, _} = Posts.create_bookmark(user.id, saved.id)

      data =
        conn
        |> get("/api/v1/search?grouped=true&q=taco")
        |> json_response(200)
        |> Map.fetch!("data")

      assert Enum.map(data["tray"], & &1["id"]) == [saved.id]
      assert data["following"] == []
      assert data["everyone"] == []
    end

    test "photo posts never appear in grouped, group or browse results", %{conn: conn} do
      post_fixture(%{user_id: user_fixture().id, caption: "taco", type: "post"})

      grouped = conn |> get("/api/v1/search?grouped=true&q=taco") |> json_response(200)
      assert grouped["data"]["everyone"] == []

      group = conn |> get("/api/v1/search?group=everyone&q=taco") |> json_response(200)
      assert group["data"]["posts"] == []

      browse = conn |> get("/api/v1/search/browse") |> json_response(200)
      assert browse["data"]["most_saved"] == []
    end

    test "category supplies the query", %{conn: conn, user: user} do
      quick = post_fixture(%{user_id: user.id, cooking_time_minutes: 20})
      _slow = post_fixture(%{user_id: user.id, cooking_time_minutes: 90})

      data =
        conn
        |> get("/api/v1/search?grouped=true&category=quick_dinners")
        |> json_response(200)
        |> Map.fetch!("data")

      assert Enum.map(data["tray"], & &1["id"]) == [quick.id]
    end

    test "an unknown category is ignored", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id, cooking_time_minutes: 90})

      data =
        conn
        |> get("/api/v1/search?grouped=true&category=nope")
        |> json_response(200)
        |> Map.fetch!("data")

      assert Enum.map(data["tray"], & &1["id"]) == [post.id]
    end

    test "ads interleave into everyone when in-app ads are on", %{conn: conn, original: original} do
      enable_in_app_ads(original)
      author = user_fixture()
      for i <- 1..9, do: post_fixture(%{user_id: author.id, caption: "taco #{i}"})

      data =
        conn
        |> get("/api/v1/search?grouped=true&q=taco")
        |> json_response(200)
        |> Map.fetch!("data")

      assert Enum.any?(
               data["everyone"],
               &(&1["type"] == "ad" and &1["ad"]["placement"] == "find")
             )
    end
  end

  describe "GET /api/v1/search?group=..." do
    test "group=tray pages one group as FeedItems", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id, caption: "taco"})

      body = conn |> get("/api/v1/search?group=tray&q=taco") |> json_response(200)
      assert [%{"type" => "post"}] = body["data"]["posts"]
      assert Map.has_key?(body, "cursor")
      assert Map.has_key?(body, "ad_config")
    end

    test "group=everyone follows the cursor to the next page", %{conn: conn} do
      author = user_fixture()
      for i <- 1..21, do: post_fixture(%{user_id: author.id, caption: "taco #{i}"})

      first = conn |> get("/api/v1/search?group=everyone&q=taco") |> json_response(200)
      assert length(first["data"]["posts"]) == 20

      second =
        conn
        |> get("/api/v1/search?group=everyone&q=taco&cursor=#{first["cursor"]}")
        |> json_response(200)

      assert [%{"type" => "post"}] = second["data"]["posts"]
    end

    test "no ads in tray or following even when in-app ads are on", %{
      conn: conn,
      user: user,
      original: original
    } do
      enable_in_app_ads(original)
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(user, friend)

      for i <- 1..9 do
        post_fixture(%{user_id: user.id, caption: "taco #{i}"})
        post_fixture(%{user_id: friend.id, caption: "taco #{i}"})
      end

      for group <- ~w(tray following) do
        posts =
          conn
          |> get("/api/v1/search?group=#{group}&q=taco")
          |> json_response(200)
          |> get_in(["data", "posts"])

        assert length(posts) == 9
        assert Enum.all?(posts, &(&1["type"] == "post"))
      end
    end
  end

  describe "GET /api/v1/search/browse" do
    test "browse returns categories and most saved", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id})

      body = conn |> get("/api/v1/search/browse") |> json_response(200)
      data = body["data"]
      assert length(data["categories"]) == 6
      assert hd(data["categories"]) == %{"key" => "quick_dinners", "label" => "Quick dinners"}
      assert [%{"type" => "post"}] = data["most_saved"]
      assert Map.has_key?(body, "ad_config")
    end

    test "most saved skips blocked authors", %{conn: conn, user: user} do
      blocked = user_fixture()
      post = post_fixture(%{user_id: blocked.id})
      Posts.create_bookmark(user_fixture().id, post.id)
      Accounts.block_user(blocked.id, user.id)

      data = conn |> get("/api/v1/search/browse") |> json_response(200) |> Map.fetch!("data")
      assert data["most_saved"] == []
    end

    test "requires authentication" do
      conn = build_conn() |> put_req_header("accept", "application/json")
      assert conn |> get("/api/v1/search/browse") |> json_response(401)
    end
  end
end
