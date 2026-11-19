defmodule TraysSocialWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use TraysSocialWeb, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates/1 call below
  # and add pages to the error directory:
  #
  #   * lib/trays_social_web/controllers/error_html/404.html.heex
  #   * lib/trays_social_web/controllers/error_html/500.html.heex
  #
  # embed_templates "error_html/*"

  # D128: a 403 on an HTML request is almost always a form posted with a stale
  # CSRF token (sent twice, or left open across a sign-in or sign-out), so say
  # how to recover instead of a bare "Forbidden". Generic on purpose: it does
  # not say which check failed.
  def render("403.html", _assigns) do
    "This form has expired. Go back, reload the page and try again."
  end

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
