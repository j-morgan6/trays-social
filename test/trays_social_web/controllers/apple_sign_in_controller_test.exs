defmodule TraysSocialWeb.AppleSignInControllerTest do
  use TraysSocialWeb.ConnCase, async: false

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocial.Repo

  @services_id "com.trays.social.web"

  setup do
    original_services_id = Application.get_env(:trays_social, :apple_services_id)
    original_verifier = Application.get_env(:trays_social, :apple_token_verifier)

    Application.put_env(:trays_social, :apple_services_id, @services_id)

    # Use the existing mock from test/support/mocks/apple_auth_mock.ex.
    # It returns known {:ok, claims} maps for fixed token strings, so we
    # don't need to construct real Apple-signed JWTs in tests.
    Application.put_env(:trays_social, :apple_token_verifier, TraysSocial.Accounts.AppleAuthMock)

    on_exit(fn ->
      if original_services_id do
        Application.put_env(:trays_social, :apple_services_id, original_services_id)
      else
        Application.delete_env(:trays_social, :apple_services_id)
      end

      if original_verifier do
        Application.put_env(:trays_social, :apple_token_verifier, original_verifier)
      else
        Application.delete_env(:trays_social, :apple_token_verifier)
      end
    end)

    :ok
  end

  describe "GET /auth/apple/start" do
    test "redirects to Apple authorize URL with a signed state token", %{conn: conn} do
      conn = get(conn, ~p"/auth/apple/start")

      target = redirected_to(conn, 302)
      assert target =~ "https://appleid.apple.com/auth/authorize"
      assert target =~ "client_id=" <> @services_id
      assert target =~ "response_mode=form_post"
      assert target =~ "scope=name+email"
      assert state = extract_state(target)
      assert String.length(state) > 16
    end

    test "redirects back to login with a flash error when APPLE_SERVICES_ID is unset",
         %{conn: conn} do
      Application.delete_env(:trays_social, :apple_services_id)

      conn = get(conn, ~p"/auth/apple/start")

      assert redirected_to(conn, 302) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not available"
    end
  end

  describe "POST /auth/apple/callback" do
    test "logs the user in on a valid id_token + signed state (new user)", %{conn: conn} do
      state = state_from_start(conn)

      conn =
        build_conn()
        |> post(~p"/auth/apple/callback", %{
          "id_token" => "valid_apple_token",
          "state" => state,
          "code" => "ignored_we_dont_exchange"
        })

      assert redirected_to(conn, 302)
      assert get_session(conn, :user_token)

      # find_or_create_apple_user inserted a row with the mock's apple_id.
      assert %User{apple_id: "apple_user_001"} =
               Repo.get_by(User, apple_id: "apple_user_001")
    end

    test "logs in the existing user when apple_id is already known (no duplicate row)",
         %{conn: conn} do
      # Pre-existing Apple user matching the mock's "existing_apple_token".
      {:ok, _existing} =
        Accounts.find_or_create_apple_user(%{
          apple_id: "existing_apple_user",
          email: "existing@apple.com",
          username: "existinguser"
        })

      assert Repo.aggregate(User, :count) == 1

      state = state_from_start(conn)

      conn =
        build_conn()
        |> post(~p"/auth/apple/callback", %{
          "id_token" => "existing_apple_token",
          "state" => state
        })

      assert redirected_to(conn, 302)
      assert get_session(conn, :user_token)

      # No duplicate row.
      assert Repo.aggregate(User, :count) == 1
    end

    test "rejects callback when state signature is invalid (replay/forgery protection)",
         %{conn: conn} do
      conn =
        post(conn, ~p"/auth/apple/callback", %{
          "id_token" => "valid_apple_token",
          "state" => "completely_fabricated_state_with_no_signature"
        })

      assert redirected_to(conn, 302) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "could not be verified"
      refute get_session(conn, :user_token)
      assert Repo.aggregate(User, :count) == 0
    end

    test "rejects callback when state is missing entirely", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/apple/callback", %{
          "id_token" => "valid_apple_token"
        })

      assert redirected_to(conn, 302) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
      assert Repo.aggregate(User, :count) == 0
    end

    test "rejects callback when id_token is invalid", %{conn: conn} do
      state = state_from_start(conn)

      conn =
        build_conn()
        |> post(~p"/auth/apple/callback", %{
          "id_token" => "this_is_not_a_valid_token",
          "state" => state
        })

      assert redirected_to(conn, 302) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "failed"
      refute get_session(conn, :user_token)
      assert Repo.aggregate(User, :count) == 0
    end

    test "rejects callback when APPLE_SERVICES_ID is missing at request time", %{conn: conn} do
      state = state_from_start(conn)

      Application.delete_env(:trays_social, :apple_services_id)

      conn =
        build_conn()
        |> post(~p"/auth/apple/callback", %{
          "id_token" => "valid_apple_token",
          "state" => state
        })

      assert redirected_to(conn, 302) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not available"
      refute get_session(conn, :user_token)
    end

    test "rejects callback missing the id_token form field", %{conn: conn} do
      state = state_from_start(conn)

      conn =
        build_conn()
        |> post(~p"/auth/apple/callback", %{"state" => state})

      assert redirected_to(conn, 302) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end
  end

  ## ---------- helpers ----------

  # Runs the /start action and returns the signed state token extracted
  # from the resulting Apple authorize redirect URL. Mirrors what a real
  # browser would carry across the redirect → form_post round trip.
  defp state_from_start(conn) do
    conn = get(conn, ~p"/auth/apple/start")
    extract_state(redirected_to(conn, 302))
  end

  defp extract_state(authorize_url) do
    %URI{query: query} = URI.parse(authorize_url)
    URI.decode_query(query)["state"]
  end
end
