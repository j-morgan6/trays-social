defmodule TraysSocialWeb.LegalController do
  @moduledoc """
  Serves the public-facing legal documents (Privacy Policy + Terms of Service).

  Markdown sources live at `priv/legal/{privacy,terms}.md`. They are parsed at
  compile-time via `TraysSocialWeb.LegalDocParser` (which uses Earmark) and
  embedded as module attributes — no per-request parsing, malformed markdown
  fails the build instead of a runtime request.

  Each markdown file begins with a YAML-style frontmatter block:

      ---
      effective_date: 2026-05-07
      version: 1.0
      ---

  The frontmatter is parsed into the page header. The rest of the file is
  rendered to HTML once at compile time.
  """

  use TraysSocialWeb, :controller

  alias TraysSocialWeb.LegalDocParser

  @privacy_path Application.app_dir(:trays_social, "priv/legal/privacy.md")
  @terms_path Application.app_dir(:trays_social, "priv/legal/terms.md")
  @community_guidelines_path Application.app_dir(
                               :trays_social,
                               "priv/legal/community-guidelines.md"
                             )
  @faq_path Application.app_dir(:trays_social, "priv/legal/faq.md")

  @external_resource @privacy_path
  @external_resource @terms_path
  @external_resource @community_guidelines_path
  @external_resource @faq_path

  @privacy LegalDocParser.parse(@privacy_path)
  @terms LegalDocParser.parse(@terms_path)
  @community_guidelines LegalDocParser.parse(@community_guidelines_path)
  @faq LegalDocParser.parse(@faq_path)

  def privacy(conn, _params), do: render_doc(conn, @privacy, "Privacy Policy")

  def terms(conn, _params), do: render_doc(conn, @terms, "Terms of Service")

  def community_guidelines(conn, _params),
    do: render_doc(conn, @community_guidelines, "Community Guidelines")

  def faq(conn, _params), do: render_doc(conn, @faq, "FAQ")

  # W159: CCPA "Do Not Sell or Share" preference page. Unlike the markdown
  # docs above this is stateful per visitor (reads the opt-out cookie), so it
  # must never be cached by shared caches — hence private, no-store instead
  # of render_doc's public, max-age.
  def ads_choices(conn, _params) do
    conn
    |> put_resp_header("cache-control", "private, no-store")
    |> put_root_layout(false)
    |> put_layout(false)
    |> render(:ads_choices,
      title: "Advertising Choices",
      opted_out: conn.cookies["trays_ads_opt_out"] == "1"
    )
  end

  # Sets or clears the first-party opt-out preference cookie. http_only is
  # deliberately false: the AdSlot JS hook reads the cookie client-side
  # before requesting any ad script, and the cookie carries no identifier —
  # its value is the literal "1", so exposure to JS is harmless.
  def update_ads_choices(conn, %{"choice" => "opt_out"}) do
    conn
    |> put_resp_cookie("trays_ads_opt_out", "1",
      max_age: 31_536_000,
      http_only: false,
      same_site: "Lax"
    )
    |> redirect(to: ~p"/privacy/ads-choices")
  end

  def update_ads_choices(conn, %{"choice" => "opt_in"}) do
    conn
    |> delete_resp_cookie("trays_ads_opt_out")
    |> redirect(to: ~p"/privacy/ads-choices")
  end

  # Unknown/missing choice — redirect back without touching the cookie.
  def update_ads_choices(conn, _params) do
    redirect(conn, to: ~p"/privacy/ads-choices")
  end

  defp render_doc(conn, doc, title) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> put_root_layout(false)
    |> put_layout(false)
    |> render(:legal,
      title: title,
      effective_date: doc.effective_date,
      version: doc.version,
      body_html: doc.body_html
    )
  end
end
