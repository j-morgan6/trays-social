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
