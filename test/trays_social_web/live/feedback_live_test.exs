defmodule TraysSocialWeb.FeedbackLiveTest do
  use TraysSocialWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Feedback
  alias TraysSocial.Feedback.Submission
  alias TraysSocial.Repo

  defp stored_count(user),
    do: user |> owned_query() |> Repo.aggregate(:count)

  defp owned_query(user), do: from(s in Submission, where: s.user_id == ^user.id)

  defp stored_count_all, do: Submission |> Repo.aggregate(:count)

  defp stored_row(user), do: user |> owned_query() |> Repo.one!()

  defp open(conn, user, path \\ ~p"/feedback") do
    {:ok, view, _html} = conn |> log_in_user(user) |> live(path)
    view
  end

  defp send_report(view, params) do
    view |> form("#feedback-form", feedback: params) |> render_submit()
  end

  defp textarea_text(view) do
    view
    |> element("textarea#feedback_body")
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.text()
  end

  describe "sending a report" do
    test "a signed-in user submits a bug report and sees the thank-you state", %{conn: conn} do
      user = user_fixture()
      view = open(conn, user)

      html =
        send_report(view, %{
          kind: "bug",
          subject: "Photo upload",
          body: "The upload spins forever."
        })

      assert html =~ "Thanks for telling us"
      assert has_element?(view, "#feedback-sent[role=status]")
      refute has_element?(view, "#feedback-form")

      row = stored_row(user)
      assert row.kind == "bug"
      assert row.subject == "Photo upload"
      assert row.body == "The upload spins forever."
      assert row.status == "new"
    end

    test "the stored row has platform web, the user agent and the from path as screen",
         %{conn: conn} do
      user = user_fixture()
      ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) Safari/605.1.15"

      view =
        conn
        |> Plug.Conn.put_req_header("user-agent", ua)
        |> open(user, ~p"/feedback?from=/users/settings")

      send_report(view, %{kind: "feedback", body: "Love the new My Tray."})

      row = stored_row(user)
      assert row.platform == "web"
      assert row.user_agent == ua
      assert row.screen == "/users/settings"
      assert row.kind == "feedback"
      assert row.app_build == nil
    end

    test "an unconfirmed user can open /feedback and send a report", %{conn: conn} do
      user = unconfirmed_user_fixture()
      view = open(conn, user, ~p"/feedback?kind=bug&from=/users/confirm-required")

      send_report(view, %{body: "The confirmation email never arrives."})

      assert has_element?(view, "#feedback-sent")
      assert stored_row(user).screen == "/users/confirm-required"
      assert stored_row(user).kind == "bug"
    end

    test "?kind=feedback preselects Feedback, and Bug is the default", %{conn: conn} do
      user = user_fixture()

      assert conn |> open(user) |> has_element?("#feedback_kind_bug[checked]")

      assert conn
             |> open(user, ~p"/feedback?kind=feedback")
             |> has_element?("#feedback_kind_feedback[checked]")

      assert conn
             |> open(user, ~p"/feedback?kind=nonsense")
             |> has_element?("#feedback_kind_bug[checked]")
    end

    test "switching between Bug and Feedback keeps the typed text", %{conn: conn} do
      user = user_fixture()
      view = open(conn, user)

      view
      |> form("#feedback-form", feedback: %{kind: "feedback", body: "A long bug report"})
      |> render_change()

      assert has_element?(view, "#feedback_kind_feedback[checked]")
      assert textarea_text(view) =~ "A long bug report"
    end

    test "send another returns to an empty form", %{conn: conn} do
      user = user_fixture()
      view = open(conn, user)
      send_report(view, %{kind: "feedback", body: "First one"})

      view |> element("#feedback-send-another") |> render_click()

      assert has_element?(view, "#feedback-form")
      assert has_element?(view, "#feedback_kind_feedback[checked]")
      refute textarea_text(view) =~ "First one"
    end
  end

  describe "refused in place" do
    test "an empty message shows an amber field error and stores nothing", %{conn: conn} do
      user = user_fixture()
      view = open(conn, user)

      html = send_report(view, %{kind: "bug", subject: "Keep this subject", body: "   "})

      assert has_element?(view, "#feedback-form p.bg-accent\\/25", "can't be blank")
      assert has_element?(view, "textarea#feedback_body[aria-invalid=true]")
      assert html =~ "Keep this subject"
      refute has_element?(view, "#feedback-sent")
      assert stored_count(user) == 0
    end

    test "a message over 5,000 characters is rejected in place", %{conn: conn} do
      user = user_fixture()
      view = open(conn, user)
      body = String.duplicate("a", 5001)

      send_report(view, %{kind: "bug", body: body})

      assert has_element?(view, "#feedback-form p.bg-accent\\/25", "should be at most 5000")
      assert textarea_text(view) =~ body
      assert has_element?(view, "#feedback-body-count", "5,001 / 5,000")
      assert stored_count(user) == 0
    end

    test "the character counter and the server's 5,000 limit agree", %{conn: conn} do
      user = user_fixture()
      view = open(conn, user)

      # Graphemes, after trimming: a combining mark is one character, and
      # surrounding whitespace does not count, exactly as Submission counts.
      body = "  " <> String.duplicate("é", Submission.body_max_length()) <> "\n"

      view |> form("#feedback-form", feedback: %{body: body}) |> render_change()
      assert has_element?(view, "#feedback-body-count", "5,000 / 5,000")

      send_report(view, %{kind: "feedback", body: body})
      assert has_element?(view, "#feedback-sent")
      assert stored_count(user) == 1
    end

    test "a from value that is not a relative path is dropped", %{conn: conn} do
      user = user_fixture()
      long = "/" <> String.duplicate("a", 120)

      for from <- ["//evil.example", "https://evil.example", "/\\evil.example", "settings", long] do
        view = open(conn, user, "/feedback?" <> URI.encode_query(%{"from" => from}))
        send_report(view, %{kind: "bug", body: "from #{inspect(from)}"})
      end

      assert user |> owned_query() |> Repo.all() |> Enum.map(& &1.screen) ==
               [nil, nil, nil, nil, nil]

      # A list from ?from[]= is dropped too, and 120 characters are kept.
      view = open(conn, user, "/feedback?from[]=/users/settings")
      send_report(view, %{kind: "bug", body: "list from"})

      ok = "/" <> String.duplicate("a", 119)
      view = open(conn, user, "/feedback?" <> URI.encode_query(%{"from" => ok}))
      send_report(view, %{kind: "bug", body: "kept from"})

      screens = user |> owned_query() |> select([s], {s.body, s.screen}) |> Repo.all()

      assert {"list from", nil} in screens
      assert {"kept from", ok} in screens
    end
  end

  describe "access" do
    test "a signed-out visitor is redirected to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/feedback")
    end

    test "an expired session sends the user to log in instead of the form", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      token = Plug.Conn.get_session(conn, :user_token)
      Accounts.delete_user_session_token(token)

      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/feedback")
    end

    # Change the Rights: the session expires while the form is open. The
    # open socket keeps the scope it authenticated at mount, as every
    # LiveView in the app does, so a send from it is still the signed-in
    # user's and is stored rather than lost. Log-out also broadcasts
    # "disconnect" on the session's live_socket_id (UserAuth.log_out_user/1),
    # and the reconnect, which mounts from the page's signed LiveView
    # session, finds no user and is sent to log in.
    test "the session expires while the form is open; nothing crashes and the reconnect goes to log in",
         %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      rendered = get(conn, ~p"/feedback")
      assert html_response(rendered, 200) =~ "Report a problem"
      {:ok, view, _html} = live(rendered)

      conn |> Plug.Conn.get_session(:user_token) |> Accounts.delete_user_session_token()

      send_report(view, %{kind: "bug", body: "Sent as my session ended"})
      assert Process.alive?(view.pid)
      assert has_element?(view, "#feedback-sent")
      assert stored_row(user).body == "Sent as my session ended"

      # The reconnect: the same rendered page connects again. Only the
      # LiveView's on_mount runs here (no router plug), and it redirects.
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(rendered)
    end

    test "a plain POST to /feedback is not routed", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      conn = post(conn, "/feedback", %{"feedback" => %{"body" => "x"}})

      assert conn.status == 404
      assert stored_count_all() == 0
    end

    test "the admin feedback list shows the new web row", %{conn: conn} do
      user = user_fixture()
      conn |> open(user) |> send_report(%{kind: "bug", body: "Shows up for the admin"})

      assert [%{platform: "web", body: "Shows up for the admin"}] =
               Feedback.list_recent(platform: "web") |> Enum.filter(&(&1.user_id == user.id))

      {:ok, admin} = Accounts.set_admin(user_fixture(), true)
      {:ok, _view, html} = build_conn() |> log_in_user(admin) |> live(~p"/admin/feedback")
      assert html =~ "Shows up for the admin"
    end
  end
end

defmodule TraysSocialWeb.FeedbackLiveRateLimitTest do
  # Not async: these tests switch off the global :disable_rate_limiting
  # flag (turning rate limiting on), and Hammer's buckets are process-global.
  use TraysSocialWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Feedback.Submission
  alias TraysSocial.Repo

  setup do
    Application.put_env(:trays_social, :disable_rate_limiting, false)
    on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)

    # A fresh client address per test, through the trusted proxy header the
    # endpoint reads (TrustedRemoteIp), so the per-address bucket is new.
    ip = "198.51.100.#{rem(System.unique_integer([:positive]), 250) + 1}"
    %{conn: Plug.Conn.put_req_header(build_conn(), "x-forwarded-for", ip)}
  end

  defp stored_count(user),
    do: user |> owned_query() |> Repo.aggregate(:count)

  defp owned_query(user), do: from(s in Submission, where: s.user_id == ^user.id)

  defp send_reports(conn, user, n) do
    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/feedback")

    for i <- 1..n//1 do
      view |> form("#feedback-form", feedback: %{body: "Report #{i}"}) |> render_submit()
      view |> element("#feedback-send-another") |> render_click()
    end

    view
  end

  test "the sixth submission in an hour shows the rate-limit message and stores nothing",
       %{conn: conn} do
    user = user_fixture()
    view = send_reports(conn, user, 5)

    html =
      view
      |> form("#feedback-form", feedback: %{kind: "bug", body: "The sixth report"})
      |> render_submit()

    assert has_element?(view, "#feedback-rate-limited[role=alert]")
    assert html =~ "The sixth report"
    refute has_element?(view, "#feedback-sent")
    assert stored_count(user) == 5
  end

  test "the per-user limit is shared with the API", %{conn: conn} do
    user = user_fixture()

    for _ <- 1..5, do: TraysSocialWeb.FeedbackRateLimit.check_submission(user.id)

    view = send_reports(conn, user, 0)
    view |> form("#feedback-form", feedback: %{body: "After five from iOS"}) |> render_submit()

    assert has_element?(view, "#feedback-rate-limited")
    assert stored_count(user) == 0
  end

  test "the 21st submission from one address across accounts is refused", %{conn: conn} do
    users = for _ <- 1..4, do: user_fixture()
    Enum.each(users, &send_reports(conn, &1, 5))

    late = user_fixture()
    view = send_reports(conn, late, 0)
    view |> form("#feedback-form", feedback: %{body: "From the same network"}) |> render_submit()

    assert has_element?(view, "#feedback-rate-limited")
    assert stored_count(late) == 0
  end
end
