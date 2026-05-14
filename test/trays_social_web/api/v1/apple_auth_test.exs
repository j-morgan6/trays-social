defmodule TraysSocialWeb.API.V1.AppleAuthTest do
  # async: false — several regression tests mutate :admin_emails app config,
  # which is process-wide and would race with other async test modules.
  use TraysSocialWeb.ConnCase, async: false

  # The matching raw nonce for the mock's fixed nonce claim. The mock returns
  # `claims["nonce"]` = SHA-256 hex of this string for every "valid_*" token
  # so the W104 nonce-validation branch in AppleAuth.verify_token/2 succeeds
  # without each test having to compute the hash.
  @raw_nonce TraysSocial.Accounts.AppleAuthMock.test_nonce_raw()

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/v1/auth/apple" do
    test "creates new user and returns token with needs_username", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          raw_nonce: @raw_nonce,
          email: "apple@privaterelay.appleid.com"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["token"])
      assert data["needs_username"] == true
      assert data["user"]["email"] == "apple@privaterelay.appleid.com"
      # Regression: first-time Apple users have no username yet. The response
      # must serialize the missing username as an empty string, NOT nil/null —
      # the iOS client decodes `username` as a non-optional String and a null
      # value crashes the decoder before the `needs_username` flag is read.
      assert data["user"]["username"] == ""
      refute is_nil(data["user"]["username"])
    end

    test "creates user with username when provided", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          raw_nonce: @raw_nonce,
          email: "apple@privaterelay.appleid.com",
          username: "appleuser"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["needs_username"] == false
      assert data["user"]["username"] == "appleuser"
    end

    test "returns existing user on subsequent sign-in", %{conn: conn} do
      # First sign-in creates user
      user = create_apple_user("existing_apple_user", "existing@apple.com")

      # Second sign-in finds existing user
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "existing_apple_token",
          raw_nonce: @raw_nonce
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["user"]["id"] == user.id
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "invalid_token",
          raw_nonce: @raw_nonce
        })

      assert %{"errors" => [%{"message" => "unauthorized"}]} = json_response(conn, 401)
    end

    test "returns 422 when identity_token missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/apple", %{})

      assert %{"errors" => [%{"message" => "identity_token is required"}]} =
               json_response(conn, 422)
    end

    test "uses email from claims when not provided in params", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          raw_nonce: @raw_nonce
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["user"]["email"] == "apple@privaterelay.appleid.com"
    end

    test "ignores params[email] in favor of the verified JWT claim", %{conn: conn} do
      # D37 regression: an attacker with a valid Apple token must not be able
      # to spoof the persisted email by passing params["email"]. The stored
      # email must come from the verified JWT claim, never from client input.
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          raw_nonce: @raw_nonce,
          email: "victim@example.com"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["user"]["email"] == "apple@privaterelay.appleid.com"
      refute data["user"]["email"] == "victim@example.com"
    end

    test "spoofed admin email param does NOT grant is_admin", %{conn: conn} do
      # D37 regression: previously, params["email"] = <allowlisted admin email>
      # alongside any valid Apple identity token resulted in an admin session.
      # Lock in that Apple Sign In can never auto-grant admin, regardless of
      # what email the client passes.
      original = Application.get_env(:trays_social, :admin_emails)
      Application.put_env(:trays_social, :admin_emails, ["admin-target@example.com"])

      try do
        conn =
          post(conn, ~p"/api/v1/auth/apple", %{
            identity_token: "valid_apple_token",
            raw_nonce: @raw_nonce,
            email: "admin-target@example.com"
          })

        assert %{"data" => data} = json_response(conn, 201)
        assert data["user"]["is_admin"] == false
        # And the persisted email is the claim email, not the spoofed param.
        assert data["user"]["email"] == "apple@privaterelay.appleid.com"
      after
        Application.put_env(:trays_social, :admin_emails, original)
      end
    end

    test "subsequent sign-in with no email claim does NOT overwrite stored email", %{conn: conn} do
      # Apple omits the email claim on every sign-in after the first. The
      # existing user must be looked up by apple_id alone and their stored
      # email left untouched — and crucially, the client cannot inject a
      # spoofed email via params on those subsequent requests.
      user = create_apple_user("apple_user_002", "real@example.com")

      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token_no_email",
          raw_nonce: @raw_nonce,
          email: "attacker@example.com"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["user"]["id"] == user.id
      assert data["user"]["email"] == "real@example.com"
    end

    test "Apple Sign In with claim email in admin allowlist still does NOT grant admin", %{
      conn: conn
    } do
      # Even if Apple returns a claim email that happens to be in the
      # allowlist, Apple Sign In must not auto-grant admin — email from the
      # Apple JWT is not an authentication factor for privilege escalation.
      original = Application.get_env(:trays_social, :admin_emails)
      Application.put_env(:trays_social, :admin_emails, ["apple@privaterelay.appleid.com"])

      try do
        conn =
          post(conn, ~p"/api/v1/auth/apple", %{
            identity_token: "valid_apple_token",
            raw_nonce: @raw_nonce
          })

        assert %{"data" => data} = json_response(conn, 201)
        assert data["user"]["is_admin"] == false
      after
        Application.put_env(:trays_social, :admin_emails, original)
      end
    end

    test "rejects request with missing raw_nonce (W104)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token"
        })

      assert %{"errors" => [%{"message" => "raw_nonce is required"}]} =
               json_response(conn, 422)
    end

    test "rejects request with empty raw_nonce (W104)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          raw_nonce: ""
        })

      assert %{"errors" => [%{"message" => "raw_nonce is required"}]} =
               json_response(conn, 422)
    end

    test "rejects token whose nonce claim doesn't match sha256(raw_nonce) (W104)", %{conn: conn} do
      # The mock returns nonce = sha256("test_nonce_raw"). Sending a different
      # raw_nonce simulates an attacker replaying a captured Apple token with
      # their own raw_nonce — the hashes won't match.
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          raw_nonce: "attacker_nonce"
        })

      assert %{"errors" => [%{"message" => "unauthorized"}]} = json_response(conn, 401)
    end

    test "rejects token with no nonce claim at all (W104)", %{conn: conn} do
      # The mock token "valid_apple_token_no_nonce" returns claims without a
      # nonce key. The server must reject — a token issued without a nonce
      # binding cannot be safely accepted regardless of raw_nonce.
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token_no_nonce",
          raw_nonce: @raw_nonce
        })

      assert %{"errors" => [%{"message" => "unauthorized"}]} = json_response(conn, 401)
    end
  end

  defp create_apple_user(apple_id, email) do
    {:ok, user} =
      %TraysSocial.Accounts.User{}
      |> Ecto.Changeset.change(%{
        apple_id: apple_id,
        email: email,
        username: "existingapple",
        confirmed_at: DateTime.utc_now(:second)
      })
      |> TraysSocial.Repo.insert()

    user
  end
end
