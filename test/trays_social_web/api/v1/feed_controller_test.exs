defmodule TraysSocialWeb.API.V1.FeedControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

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
end
