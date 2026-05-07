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

  def aasa(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> json(@aasa)
  end
end
