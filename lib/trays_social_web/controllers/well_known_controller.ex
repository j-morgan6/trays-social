defmodule TraysSocialWeb.WellKnownController do
  @moduledoc """
  Serves files in the `/.well-known/` namespace required by various platform
  integrations.

  Currently:
    * `apple-app-site-association` — Apple Universal Links discovery file. Apple's
      CDN fetches this once per app install and caches it aggressively. The file
      must be served as `application/json` with no redirects, no auth, and no SSL
      negotiation issues.
  """

  use TraysSocialWeb, :controller

  # Apple App Site Association (AASA).
  #
  # `appID` = `<TEAM_ID>.<BUNDLE_ID>`. Both come from
  # `ios/TraysSocial/project.yml` (DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER).
  #
  # Paths whitelist what URLs the iOS app intercepts as Universal Links. Keeping
  # this restricted to `/users/confirm/*` avoids unintended capture for the rest
  # of trays.app (e.g., a user browsing /@username from another app should still
  # open in Safari, not redirect into Trays).
  @aasa %{
    applinks: %{
      apps: [],
      details: [
        %{
          appID: "6TN2AZM26U.com.trays.social",
          paths: ["/users/confirm/*"]
        }
      ]
    }
  }

  # Pre-encode at compile time so the runtime path serves a fixed binary —
  # no JSON re-encoding, no charset suffix, no chance of variation.
  @aasa_json Jason.encode!(@aasa)

  # D35 root cause: Bandit gzip-encodes responses when the client sends
  # Accept-Encoding: gzip. Apple's swcd daemon historically fails to register
  # AASA when the response is content-encoded — and "Don't gzip-compress the
  # AASA response" is an explicit pitfall in the Universal Links docs.
  # `content-encoding: identity` is the standard opt-out; `cache-control:
  # no-transform` additionally forbids any intermediary (Fly proxy, CDN) from
  # re-encoding on the way out. Both belts-and-suspenders for swcd.
  def aasa(conn, _params) do
    conn
    |> put_resp_content_type("application/json", nil)
    |> put_resp_header("content-encoding", "identity")
    |> put_resp_header("cache-control", "public, max-age=3600, no-transform")
    |> send_resp(200, @aasa_json)
  end
end
