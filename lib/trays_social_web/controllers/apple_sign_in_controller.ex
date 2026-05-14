defmodule TraysSocialWeb.AppleSignInController do
  @moduledoc """
  Web Sign in with Apple — services-redirect flow (D64).

  Flow:

    1. User clicks "Sign in with Apple" on /users/log-in → GET
       /auth/apple/start. The action generates a signed state token bound to
       the session, then 302-redirects to Apple's authorize URL with
       response_mode=form_post.

    2. User authenticates with Apple. Apple POSTs back to
       /auth/apple/callback with form fields: state, code, id_token, and
       (first-time only) user.

    3. The callback verifies the state against the session, verifies the
       id_token via `TraysSocial.Accounts.AppleAuth` with the Services ID as
       the expected aud, looks up or creates the user via
       `Accounts.find_or_create_apple_user/1` (same path the iOS API uses —
       no duplicate accounts), and finally calls `UserAuth.log_in_user/2`.

  Note on client_secret: we only need the id_token from the initial
  authorize redirect. We do NOT exchange the auth code for an access_token,
  so we do NOT need to generate a client_secret JWT signed with a .p8 key.
  If a future feature requires refresh tokens or Apple-side revocation,
  add that flow then.
  """

  use TraysSocialWeb, :controller

  require Logger

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.AppleAuth
  alias TraysSocialWeb.Endpoint
  alias TraysSocialWeb.UserAuth

  @apple_authorize_url "https://appleid.apple.com/auth/authorize"
  @state_salt "apple sign in state"
  # State token is valid for 10 minutes — Apple's authorize round-trip is
  # typically under a minute; 10 gives slow users headroom without
  # accepting indefinite replay.
  @state_max_age_seconds 10 * 60

  @doc """
  Begins the web Apple Sign In flow by redirecting to Apple's authorize
  endpoint with a Phoenix.Token-signed state parameter.

  The state is a self-contained signed token (containing a random nonce
  and an embedded timestamp). It does NOT rely on the session cookie.
  This matters because Apple's form_post callback is a cross-site POST
  from appleid.apple.com to trays.app, and the browser will NOT send our
  `SameSite=Lax` session cookie on that request. A session-stored state
  would always look "missing" on the callback. Signing the state itself
  makes the flow stateless and immune to SameSite restrictions.
  """
  def start(conn, _params) do
    case services_id() do
      nil ->
        Logger.error(
          "Apple Sign In start rejected: APPLE_SERVICES_ID is not configured on this environment"
        )

        conn
        |> put_flash(:error, "Sign in with Apple is not available right now. Try email instead.")
        |> redirect(to: ~p"/users/log-in")

      services_id ->
        state = sign_state()

        redirect(conn, external: authorize_url(services_id, state))
    end
  end

  @doc """
  Handles Apple's form_post callback. Verifies the signed state, the
  id_token, and either logs in an existing user (matched by apple_id) or
  registers a new one.

  Note: this action runs in the `:browser_no_csrf` router pipeline — Apple
  POSTs from a third-party origin without our CSRF token. The signed state
  token is the replay-protection layer that compensates.
  """
  def callback(conn, %{"id_token" => id_token, "state" => state} = _params) do
    with :ok <- verify_state(state),
         {:ok, services_id} <- fetch_services_id(),
         {:ok, claims} <-
           AppleAuth.verify_token(id_token, expected_audiences: [services_id]),
         apple_id when is_binary(apple_id) <- claims["sub"],
         {:ok, user} <-
           Accounts.find_or_create_apple_user(%{
             apple_id: apple_id,
             email: claims["email"]
           }) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user)
    else
      {:error, :state_expired} ->
        Logger.warning("Apple Sign In callback rejected: state token expired")
        reject(conn, "Sign-in attempt expired. Please try again.")

      {:error, :state_invalid} ->
        Logger.warning(
          "Apple Sign In callback rejected: state signature mismatch (possible replay or tampering)"
        )

        reject(conn, "Sign-in attempt could not be verified. Please try again.")

      {:error, :missing_services_id} ->
        Logger.error(
          "Apple Sign In callback rejected: APPLE_SERVICES_ID not configured (cannot verify token aud)"
        )

        reject(conn, "Sign in with Apple is not available right now.")

      {:error, :invalid_apple_token} ->
        Logger.warning("Apple Sign In callback rejected: invalid identity_token")
        reject(conn, "Sign in with Apple failed. Please try again.")

      {:error, :apple_keys_unavailable} ->
        Logger.error("Apple Sign In callback failed: Apple JWKs endpoint unavailable")
        reject(conn, "Sign in with Apple is temporarily unavailable.")

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error(
          "Apple Sign In callback failed at find_or_create_apple_user: #{inspect(changeset.errors)}"
        )

        reject(conn, "We could not complete your sign-in. Please try again.")

      nil ->
        Logger.warning("Apple Sign In callback rejected: id_token missing required 'sub' claim")
        reject(conn, "Sign in with Apple failed. Please try again.")
    end
  end

  def callback(conn, _params) do
    Logger.warning("Apple Sign In callback rejected: missing id_token or state form fields")
    reject(conn, "Sign in with Apple failed. Please try again.")
  end

  ## ---------- private ----------

  defp authorize_url(services_id, state) do
    callback_url = url(~p"/auth/apple/callback")

    query =
      URI.encode_query(%{
        "response_type" => "code id_token",
        "response_mode" => "form_post",
        "client_id" => services_id,
        "redirect_uri" => callback_url,
        "scope" => "name email",
        "state" => state
      })

    @apple_authorize_url <> "?" <> query
  end

  defp sign_state do
    nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    Phoenix.Token.sign(Endpoint, @state_salt, nonce)
  end

  defp verify_state(state) when is_binary(state) do
    case Phoenix.Token.verify(Endpoint, @state_salt, state, max_age: @state_max_age_seconds) do
      {:ok, _nonce} -> :ok
      {:error, :expired} -> {:error, :state_expired}
      {:error, _} -> {:error, :state_invalid}
    end
  end

  defp verify_state(_), do: {:error, :state_invalid}

  defp fetch_services_id do
    case services_id() do
      nil -> {:error, :missing_services_id}
      id -> {:ok, id}
    end
  end

  defp services_id, do: Application.get_env(:trays_social, :apple_services_id)

  defp reject(conn, flash_message) do
    conn
    |> put_flash(:error, flash_message)
    |> redirect(to: ~p"/users/log-in")
  end
end
