defmodule TraysSocialWeb.PostLive.ShowAdsTest do
  # async: false — these tests mutate the application-level :features and
  # :web_ads config (same save/restore pattern as MonetizationTest).
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts

  setup do
    original_features = Application.get_env(:trays_social, :features, [])
    original_web_ads = Application.get_env(:trays_social, :web_ads, [])

    on_exit(fn ->
      Application.put_env(:trays_social, :features, original_features)
      Application.put_env(:trays_social, :web_ads, original_web_ads)
    end)

    :ok
  end

  defp put_features(features), do: Application.put_env(:trays_social, :features, features)

  defp put_web_ads(web_ads), do: Application.put_env(:trays_social, :web_ads, web_ads)

  defp slot_count(html) do
    length(String.split(html, "data-ad-slot=")) - 1
  end

  defp create_post(_context) do
    author = user_fixture()
    %{author: author, post: post_fixture(user_id: author.id)}
  end

  setup [:create_post]

  describe "sponsored slots — web_ads flag off" do
    test "renders no ad slots and no Sponsored label", %{conn: conn, post: post} do
      put_features(web_ads: false)

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      assert slot_count(html) == 0
      refute html =~ "data-ad-slot"
      refute html =~ "Sponsored"
    end
  end

  describe "sponsored slots — web_ads flag on" do
    test "anonymous viewer sees exactly two labeled slots", %{conn: conn, post: post} do
      put_features(web_ads: true)

      {:ok, view, html} = live(conn, ~p"/posts/#{post.id}")

      assert slot_count(html) == 2
      assert has_element?(view, "#ad-slot-a")
      assert has_element?(view, "#ad-slot-b")
      assert html =~ ~s|data-ad-slot="in-content-1"|
      assert html =~ ~s|data-ad-slot="in-content-2"|
      assert html =~ "Sponsored"
    end

    test "logged-in non-subscriber sees exactly two slots", %{conn: conn, post: post} do
      put_features(web_ads: true)
      viewer = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/posts/#{post.id}")

      assert slot_count(html) == 2
    end

    test "subscriber sees zero slots", %{conn: conn, post: post} do
      put_features(web_ads: true)
      {:ok, subscriber} = Accounts.set_subscriber(user_fixture(), true)

      {:ok, _view, html} =
        conn
        |> log_in_user(subscriber)
        |> live(~p"/posts/#{post.id}")

      assert slot_count(html) == 0
      refute html =~ "Sponsored"
    end
  end

  describe "sponsored slots — :web_ads script config" do
    test "configured script_url and site_id are rendered as data attributes",
         %{conn: conn, post: post} do
      put_features(web_ads: true)
      put_web_ads(script_url: "https://ads.example.com/loader.js", site_id: "trays-123")

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      assert html =~ ~s|data-script-url="https://ads.example.com/loader.js"|
      assert html =~ ~s|data-site-id="trays-123"|
    end

    test "nil config renders slots without script data attributes",
         %{conn: conn, post: post} do
      put_features(web_ads: true)
      put_web_ads(script_url: nil, site_id: nil)

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      assert slot_count(html) == 2
      refute html =~ "data-script-url"
      refute html =~ "data-site-id"
    end
  end
end
