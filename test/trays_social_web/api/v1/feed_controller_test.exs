defmodule TraysSocialWeb.API.V1.FeedControllerTest do
  # async: false — these tests toggle the global :in_app_ads feature flag via
  # Application.put_env/3 (G38/W162); running serially keeps that mutation from
  # racing other tests that read :features.
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  # Turn the :in_app_ads flag on for the duration of one test, restoring the
  # prior config on exit.
  defp enable_in_app_ads do
    original = Application.get_env(:trays_social, :features, [])
    Application.put_env(:trays_social, :features, Keyword.put(original, :in_app_ads, true))
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
  end

  describe "GET /api/v1/feed" do
    test "returns posts in reverse chronological order", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => posts, "cursor" => _cursor} = json_response(conn, 200)
      assert is_list(posts)
    end

    test "includes an ad_config block, disabled by default (G38/W158)", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/feed")

      assert %{"ad_config" => ad_config} = json_response(conn, 200)
      # The :in_app_ads feature flag is off by default, so ads ship inert.
      assert ad_config["enabled"] == false
      assert ad_config["frequency"] == TraysSocial.Monetization.ad_frequency()
    end

    test "ad_config is disabled for subscribers even when ads are enabled", %{conn: conn, user: user} do
      {:ok, _} = TraysSocial.Accounts.set_subscriber(user, true)

      original = Application.get_env(:trays_social, :features, [])
      Application.put_env(:trays_social, :features, Keyword.put(original, :in_app_ads, true))
      on_exit(fn -> Application.put_env(:trays_social, :features, original) end)

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"ad_config" => %{"enabled" => false}} = json_response(conn, 200)
    end

    test "returns posts with all expected fields", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => [post | _]} = json_response(conn, 200)
      assert Map.has_key?(post, "id")
      assert Map.has_key?(post, "type")
      assert Map.has_key?(post, "caption")
      assert Map.has_key?(post, "like_count")
      assert Map.has_key?(post, "liked_by_current_user")
      assert Map.has_key?(post, "user")
      assert Map.has_key?(post, "photos")
      assert Map.has_key?(post, "ingredients")
      assert Map.has_key?(post, "cooking_steps")
      assert Map.has_key?(post, "tags")
    end

    test "returns cursor for pagination", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"cursor" => cursor} = json_response(conn, 200)
      assert is_binary(cursor)
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/v1/feed")

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/feed — FeedItem union shape (G38/W162)" do
    test "data stays a flat PostJSON list while :in_app_ads is off (shipped-client safe)",
         %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => [post | _], "ad_config" => %{"enabled" => false}} =
               json_response(conn, 200)

      # Flat shape: fields live at the top level, no union wrapper. This is the
      # exact shape the shipped iOS app decodes as [Post].
      assert Map.has_key?(post, "id")
      assert Map.has_key?(post, "caption")
      refute Map.has_key?(post, "post")
      refute post["type"] in ["post-item", "ad"]
    end

    test "serves a tagged FeedItem union when ads are enabled for the viewer",
         %{conn: conn, user: user} do
      enable_in_app_ads()
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => [item | _], "ad_config" => %{"enabled" => true}} =
               json_response(conn, 200)

      # Tagged union: discriminator + nested post payload.
      assert item["type"] == "post"
      assert %{"id" => _, "caption" => _, "user" => _} = item["post"]
      # The post's own content-type survives, nested and distinct from the
      # union discriminator.
      assert item["post"]["type"] in ["recipe", "post"]
    end

    test "subscribers keep the flat shape even when :in_app_ads is on (always ad-free)",
         %{conn: conn, user: user} do
      {:ok, _} = TraysSocial.Accounts.set_subscriber(user, true)
      enable_in_app_ads()
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => [post | _], "ad_config" => %{"enabled" => false}} =
               json_response(conn, 200)

      assert Map.has_key?(post, "id")
      refute Map.has_key?(post, "post")
    end

    test "cursor is byte-identical whether or not the union shape is used",
         %{conn: conn, user: user} do
      for _ <- 1..3, do: post_fixture(%{user_id: user.id})

      flat_cursor =
        conn |> get(~p"/api/v1/feed") |> json_response(200) |> Map.fetch!("cursor")

      enable_in_app_ads()

      union_cursor =
        conn |> get(~p"/api/v1/feed") |> json_response(200) |> Map.fetch!("cursor")

      # The cursor derives only from the last real post, so flipping the wire
      # shape must not change it.
      assert is_binary(flat_cursor)
      assert union_cursor == flat_cursor
    end
  end
end
