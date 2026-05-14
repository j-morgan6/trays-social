defmodule TraysSocialWeb.Webhooks.ResendControllerTest do
  use TraysSocialWeb.ConnCase, async: false

  alias TraysSocial.Email
  alias TraysSocial.Email.Event
  alias TraysSocial.Repo

  @signing_secret "test-secret-not-real"

  setup do
    original = Application.get_env(:trays_social, :resend_webhook_signing_secret)

    Application.put_env(
      :trays_social,
      :resend_webhook_signing_secret,
      @signing_secret
    )

    on_exit(fn ->
      if original == nil do
        Application.delete_env(:trays_social, :resend_webhook_signing_secret)
      else
        Application.put_env(:trays_social, :resend_webhook_signing_secret, original)
      end
    end)

    :ok
  end

  describe "POST /webhooks/resend" do
    test "accepts a validly-signed event and persists it", %{conn: conn} do
      payload = sample_payload("email.delivered")
      body = Jason.encode!(payload)
      {svix_id, svix_ts, signature} = sign(body)

      conn =
        conn
        |> put_signature_headers(svix_id, svix_ts, signature)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/resend", body)

      assert response(conn, 200) == ""

      assert [%Event{event_type: "email.delivered", recipient: recipient}] =
               Repo.all(Event)

      assert recipient == "test@example.com"
    end

    test "rejects an unsigned request with 401", %{conn: conn} do
      payload = sample_payload("email.delivered")
      body = Jason.encode!(payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/resend", body)

      assert response(conn, 401) == ""
      assert Repo.aggregate(Event, :count) == 0
    end

    test "rejects a request with a tampered body (signature mismatch)", %{conn: conn} do
      payload = sample_payload("email.delivered")
      original_body = Jason.encode!(payload)
      {svix_id, svix_ts, signature} = sign(original_body)

      # Same signature, different body — Resend's signature is over the
      # exact bytes, so this MUST fail.
      tampered_body = Jason.encode!(%{payload | "type" => "email.bounced"})

      conn =
        conn
        |> put_signature_headers(svix_id, svix_ts, signature)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/resend", tampered_body)

      assert response(conn, 401) == ""
      assert Repo.aggregate(Event, :count) == 0
    end

    test "rejects an event with a timestamp outside the skew window", %{conn: conn} do
      payload = sample_payload("email.delivered")
      body = Jason.encode!(payload)

      # 10 minutes ago — outside the 5-minute window.
      old_ts = System.system_time(:second) - 10 * 60
      svix_id = "msg_test_old"
      signature = compute_sig(svix_id, old_ts, body)

      conn =
        conn
        |> put_signature_headers(svix_id, Integer.to_string(old_ts), signature)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/resend", body)

      assert response(conn, 401) == ""
      assert Repo.aggregate(Event, :count) == 0
    end

    test "is idempotent — same event_id sent twice creates one row", %{conn: _conn} do
      payload = sample_payload("email.delivered")
      body = Jason.encode!(payload)
      {svix_id, svix_ts, signature} = sign(body)

      # First call
      conn1 =
        build_conn()
        |> put_signature_headers(svix_id, svix_ts, signature)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/resend", body)

      assert response(conn1, 200)

      # Second call — same body, same signature, same event_id in the payload
      conn2 =
        build_conn()
        |> put_signature_headers(svix_id, svix_ts, signature)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/resend", body)

      assert response(conn2, 200)
      assert Repo.aggregate(Event, :count) == 1
    end

    # Note: malformed JSON is rejected by Plug.Parsers in the endpoint
    # before our controller runs (Plug.Parsers.ParseError → 400). Resend
    # only sends well-formed JSON, so this isn't a realistic ingress path.
    # The controller's Jason.DecodeError fallback exists as defense in
    # depth in case the endpoint's parser changes; not test-exercised.
  end

  describe "Email.list_recent_events/1" do
    test "filters by event_type and recipient (case-insensitive substring)" do
      {:ok, _} =
        Email.upsert_event(%{
          event_id: "ev_1",
          email_id: "em_a",
          event_type: "email.delivered",
          recipient: "Alice@Example.com",
          payload: %{}
        })

      {:ok, _} =
        Email.upsert_event(%{
          event_id: "ev_2",
          email_id: "em_b",
          event_type: "email.bounced",
          recipient: "bob@example.com",
          payload: %{}
        })

      assert [%Event{recipient: "Alice@Example.com"}] =
               Email.list_recent_events(event_type: "email.delivered")

      assert [%Event{recipient: "bob@example.com"}] =
               Email.list_recent_events(recipient: "BOB")

      assert length(Email.list_recent_events()) == 2
    end
  end

  ## ---------- helpers ----------

  defp sample_payload(event_type) do
    %{
      "id" => "evt_" <> random_id(),
      "type" => event_type,
      "data" => %{
        "email_id" => "em_" <> random_id(),
        "to" => ["test@example.com"],
        "from" => "noreply@trays.app",
        "subject" => "Log in to Trays",
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }
  end

  defp random_id, do: :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)

  defp sign(body) do
    svix_id = "msg_" <> random_id()
    svix_ts = System.system_time(:second)
    sig = compute_sig(svix_id, svix_ts, body)
    {svix_id, Integer.to_string(svix_ts), sig}
  end

  defp compute_sig(svix_id, svix_ts, body) do
    payload = "#{svix_id}.#{svix_ts}.#{body}"
    expected = :crypto.mac(:hmac, :sha256, @signing_secret, payload) |> Base.encode64()
    "v1,#{expected}"
  end

  defp put_signature_headers(conn, svix_id, svix_ts, signature) do
    conn
    |> put_req_header("svix-id", svix_id)
    |> put_req_header("svix-timestamp", svix_ts)
    |> put_req_header("svix-signature", signature)
  end
end
