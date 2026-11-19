defmodule TraysSocialWeb.ErrorHTMLTest do
  use TraysSocialWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  @app_js Path.expand("../../../assets/js/app.js", __DIR__)

  test "renders 404.html" do
    assert render_to_string(TraysSocialWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(TraysSocialWeb.ErrorHTML, "500", "html", []) ==
             "Internal Server Error"
  end

  # D128: a second login POST carried a stale CSRF token and showed a bare
  # "Forbidden" even though the first POST had logged the user in.
  describe "403" do
    test "renders 403.html as a plain explanation that the form expired" do
      body = render_to_string(TraysSocialWeb.ErrorHTML, "403", "html", [])

      assert body =~ "This form has expired"
      assert body =~ "reload the page and try again"
      refute body == "Forbidden"
    end

    test "a login POST with a stale CSRF token still gets 403, with that page", %{conn: conn} do
      conn = Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

      {403, _headers, body} =
        assert_error_sent 403, fn ->
          post(conn, ~p"/users/log-in", %{
            "_csrf_token" => "stale",
            "user" => %{"email" => "someone@example.com", "password" => "whatever123"}
          })
        end

      assert body =~ "This form has expired"
    end
  end

  # There is no JavaScript test runner in this repo, so pin the guard's
  # registration and its LiveView exclusions statically.
  describe "double-submit guard in app.js (D128)" do
    test "registers a document submit listener that skips LiveView forms" do
      js = File.read!(@app_js)

      assert js =~ ~s|document.addEventListener("submit"|
      assert js =~ ~s|form.hasAttribute("phx-submit")|
      assert js =~ ~s|form.hasAttribute("phx-change")|
      assert js =~ ~s|form.closest("[data-phx-session], [data-phx-main]")|
      assert js =~ "e.defaultPrevented"
    end

    test "finds every submit button, including a <button> with no type" do
      js = File.read!(@app_js)

      assert js =~ ~s|el.type === "submit"|
      refute js =~ ~s|querySelectorAll("button[type=submit], input[type=submit]")|
    end

    # The server-rendered auth forms: each must stay a plain form (no LiveView
    # bindings, so the guard applies) and label its busy state. The guard also
    # covers legal_html/ads_choices.html.heex, whose button has no busy text,
    # so it is only disabled.
    @dead_form_templates ~w(
      user_session_html/new.html.heex
      user_session_html/confirm.html.heex
      user_registration_html/new.html.heex
      user_reset_password_html/new.html.heex
      user_reset_password_html/edit.html.heex
      user_confirmation_html/required.html.heex
      user_settings_html/edit.html.heex
    )

    for template <- @dead_form_templates do
      @template template
      test "#{template} is a plain form whose submit button names its busy text" do
        path = Path.expand("../../../lib/trays_social_web/controllers/#{@template}", __DIR__)
        source = File.read!(path)

        assert source =~ "phx-disable-with="
        refute source =~ "phx-submit="
        refute source =~ "phx-change="
        refute source =~ "phx-trigger-action"
      end
    end

    test "blocks the second submit, disables after the data is built, and resets from bfcache" do
      js = File.read!(@app_js)

      assert js =~ ~s|form.dataset.submitting === "true"|
      assert js =~ "setTimeout("
      assert js =~ ~s|getAttribute("phx-disable-with")|
      assert js =~ ~s|window.addEventListener("pageshow"|
      assert js =~ "e.persisted"
    end
  end
end
