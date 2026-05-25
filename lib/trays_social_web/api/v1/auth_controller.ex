defmodule TraysSocialWeb.API.V1.AuthController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.AppleAuth

  def register(conn, %{"email" => email, "username" => username, "password" => password} = params) do
    age_confirmation = Map.get(params, "age_confirmation", false)

    attrs = %{
      email: email,
      username: username,
      password: password,
      age_confirmation: age_confirmation
    }

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        Accounts.deliver_user_confirmation_instructions(user, fn token ->
          TraysSocialWeb.Endpoint.url() <> "/users/confirm/" <> token
        end)

        encoded_token = Accounts.generate_user_api_token(user)

        conn
        |> put_status(:created)
        |> json(%{data: %{token: encoded_token, user: user_json(user)}})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "email, username, and password are required"}]})
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        {:error, :unauthorized}

      user ->
        encoded_token = Accounts.generate_user_api_token(user)

        json(conn, %{data: %{token: encoded_token, user: user_json(user)}})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "email and password are required"}]})
  end

  def logout(conn, _params) do
    # D54: tolerate a missing / malformed Authorization header rather than
    # crashing on a hard pattern-match. AuthPlug already gates this route
    # so the header is normally valid, but logout should be idempotent —
    # a client retrying after a half-success or with a stale bearer should
    # not see a 500.
    case get_req_header(conn, "authorization") do
      ["Bearer " <> encoded_token] ->
        Accounts.delete_user_api_token(encoded_token)

      _ ->
        :noop
    end

    json(conn, %{data: %{message: "logged out"}})
  end

  @doc """
  Issues a refresh token bound to the currently authenticated user (W105).
  Used by the iOS biometric-login flow: after a successful password / Apple
  sign-in, an opt-in to biometric prompts the client to call this endpoint
  and store the returned `refresh_token` in biometric-gated Keychain.
  """
  def create_refresh_token(conn, _params) do
    user = conn.assigns.current_user
    refresh_token = Accounts.generate_user_refresh_token(user)
    json(conn, %{data: %{refresh_token: refresh_token}})
  end

  @doc """
  Exchanges a refresh token for a fresh API bearer (W105). Unauthenticated —
  the refresh token IS the credential. Mirrors the response shape of
  `login/2` so the iOS client can reuse its auth-response decoder.
  """
  def biometric_exchange(conn, %{"refresh_token" => refresh_token})
      when is_binary(refresh_token) and byte_size(refresh_token) > 0 do
    case Accounts.exchange_refresh_token(refresh_token) do
      {:ok, {user, api_bearer}} ->
        json(conn, %{data: %{token: api_bearer, user: user_json(user)}})

      {:error, :invalid_refresh_token} ->
        {:error, :unauthorized}
    end
  end

  def biometric_exchange(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "refresh_token is required"}]})
  end

  def apple(conn, %{"identity_token" => identity_token, "raw_nonce" => raw_nonce} = params)
      when is_binary(raw_nonce) and byte_size(raw_nonce) > 0 do
    expected_nonce_hash =
      :crypto.hash(:sha256, raw_nonce) |> Base.encode16(case: :lower)

    with {:ok, claims} <-
           AppleAuth.verify_token(identity_token, expected_nonce_hash: expected_nonce_hash) do
      apple_id = claims["sub"]
      # SECURITY: email is sourced ONLY from the verified JWT claim. Never trust
      # params["email"] — a client could spoof any address (including an admin
      # allowlist entry) alongside their own valid Apple token. On subsequent
      # sign-ins Apple omits the email claim; that's fine because the existing
      # user is looked up by apple_id and the stored email is never overwritten.
      email = claims["email"]
      username = params["username"]

      attrs = %{apple_id: apple_id, email: email}
      attrs = if username, do: Map.put(attrs, :username, username), else: attrs

      case Accounts.find_or_create_apple_user(attrs) do
        {:ok, user} ->
          # generate_user_api_token already returns the URL-safe base64 form
          # that AuthPlug's verify_api_token_query/1 expects. Wrapping it in a
          # second Base.encode64/1 here (the pre-D38 pattern) produces a token
          # whose Base.url_decode64 either fails outright (on standard-base64
          # `+`/`/`) or yields bytes whose SHA-256 doesn't match the stored
          # hash — either way, every subsequent bearer call returns 401, which
          # iOS surfaces as "Session expired. Please log in again." Mirror the
          # login/2 + register/2 pattern: hand the client the encoded token
          # straight from Accounts.
          encoded_token = Accounts.generate_user_api_token(user)
          needs_username = is_nil(user.username) or user.username == ""

          status = if needs_username, do: :created, else: :ok

          conn
          |> put_status(status)
          |> json(%{
            data: %{
              token: encoded_token,
              user: user_json(user),
              needs_username: needs_username
            }
          })

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, :invalid_apple_token} ->
        {:error, :unauthorized}

      {:error, :apple_keys_unavailable} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{errors: [%{message: "Apple authentication service unavailable"}]})
    end
  end

  def apple(conn, %{"identity_token" => _}) do
    # identity_token is present but raw_nonce is missing or empty — W104 makes
    # the nonce binding mandatory to defeat captured-token replay.
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "raw_nonce is required"}]})
  end

  def apple(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "identity_token is required"}]})
  end

  @doc """
  Confirms a user's email via the registration token. Called from iOS after a
  Universal Link capture; web users hit `/users/confirm/<token>` directly.
  """
  def confirm(conn, %{"token" => token}) when is_binary(token) and token != "" do
    case Accounts.confirm_user_by_token(token) do
      {:ok, _user} ->
        json(conn, %{data: %{confirmed: true}})

      :error ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{message: "Invalid or expired confirmation token"}]})
    end
  end

  def confirm(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "token is required"}]})
  end

  def me(conn, _params) do
    user = conn.assigns.current_user
    needs_username = is_nil(user.username) or user.username == ""

    json(conn, %{data: Map.merge(user_json(user), %{needs_username: needs_username})})
  end

  def update_me(conn, params) do
    user = conn.assigns.current_user
    attrs = Map.take(params, ["username", "bio", "profile_photo_url"])

    case Accounts.update_user_profile(user, attrs) do
      {:ok, updated_user} ->
        json(conn, %{data: user_json(updated_user)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_me(conn, _params) do
    user = conn.assigns.current_user

    case Accounts.delete_account(user) do
      {:ok, _} ->
        json(conn, %{data: %{message: "account deleted"}})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: [%{message: "failed to delete account"}]})
    end
  end

  def resend_confirmation(conn, _params) do
    user = conn.assigns.current_user

    if user.confirmed_at do
      json(conn, %{data: %{message: "already confirmed"}})
    else
      Accounts.deliver_user_confirmation_instructions(user, fn token ->
        TraysSocialWeb.Endpoint.url() <> "/users/confirm/" <> token
      end)

      json(conn, %{data: %{message: "confirmation email sent"}})
    end
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      # Coerce nil to empty string so iOS clients (which decode `username` as a
      # non-optional String) can parse the response. This matters specifically
      # for first-time Sign in with Apple: the user has no username yet, and
      # the `needs_username: true` flag routes the client to UsernamePickerView
      # to set one. Returning `nil` here would JSON-serialize to `null` and
      # crash the iOS decoder before the flag can be read.
      username: user.username || "",
      bio: user.bio,
      profile_photo_url: user.profile_photo_url,
      inserted_at: user.inserted_at,
      confirmed_at: user.confirmed_at,
      # Surfaces to the iOS client so the Settings sheet can conditionally
      # render the Admin section (links to /admin/reports, /admin/errors,
      # /admin/dashboard). Per-env: flag lives on the user row in whichever
      # database the iOS build is currently talking to.
      is_admin: user.is_admin
    }
  end
end
