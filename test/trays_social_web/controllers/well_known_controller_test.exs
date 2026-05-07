defmodule TraysSocialWeb.WellKnownControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  describe "GET /.well-known/apple-app-site-association" do
    test "serves AASA JSON for Apple Universal Links discovery", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/apple-app-site-association")

      assert conn.status == 200
      # Apple requires application/json specifically; other JSON MIMEs (e.g.
      # application/vnd.api+json) cause AASA fetch to fail silently on the CDN.
      assert ["application/json" <> _] = get_resp_header(conn, "content-type")

      body = json_response(conn, 200)
      assert %{"applinks" => %{"apps" => [], "details" => details}} = body

      assert [%{"appID" => app_id, "paths" => paths}] = details
      # Bundle ID + team ID must match ios/TraysSocial/project.yml
      # (DEVELOPMENT_TEAM "6TN2AZM26U" and PRODUCT_BUNDLE_IDENTIFIER "com.trays.social")
      assert app_id == "6TN2AZM26U.com.trays.social"
      # Paths whitelist what URLs the iOS app intercepts; restricted to confirm
      # links so user-profile / explore links still open in Safari.
      assert "/users/confirm/*" in paths
    end

    test "sets cache-control for Apple's CDN", %{conn: conn} do
      conn = get(conn, ~p"/.well-known/apple-app-site-association")

      cache_control = get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control =~ "public"
      assert cache_control =~ "max-age"
    end

    test "requires no auth (no Authorization header needed)", %{conn: conn} do
      # Explicitly send a request without any Authorization header to confirm
      # the route is publicly accessible — Apple's CDN does not authenticate.
      conn = get(conn, ~p"/.well-known/apple-app-site-association")
      assert conn.status == 200
    end
  end
end
