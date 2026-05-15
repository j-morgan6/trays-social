defmodule TraysSocial.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query
  alias TraysSocial.Accounts.UserToken

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the magic link token expiry short,
  # since someone with access to the email may take over the account.
  @magic_link_validity_in_minutes 15
  @confirm_validity_in_days 7
  @change_email_validity_in_days 7
  @session_validity_in_days 14
  # API tokens back mobile sessions; 60 days matches typical mobile-app
  # re-auth cadence. There is no refresh-on-use — verifying a token does NOT
  # extend its lifetime; clients re-authenticate (password or Sign in with
  # Apple) once a token ages out.
  @api_token_validity_in_days 60
  # Refresh tokens (W105) back biometric login. Same 60-day window as API
  # tokens, no rotation-on-use. Biometric login exchanges the refresh for
  # a fresh API bearer; password change deletes all refresh tokens via
  # update_user_and_delete_all_tokens.
  @refresh_token_validity_in_days 60

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :authenticated_at, :utc_datetime
    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix's default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = user.authenticated_at || DateTime.utc_now(:second)
    {token, %UserToken{token: token, context: "session", user_id: user.id, authenticated_at: dt}}
  end

  @doc """
  Generates a token for API authentication (mobile apps).

  Returns `{encoded_token, %UserToken{}}`. The encoded token is URL-safe base64
  (no padding) and is what gets sent to the client — store it server-side only
  as a SHA-256 hash so a DB read (backup leak, replica, SQL injection elsewhere)
  cannot directly yield usable bearer tokens. This mirrors the email-token
  pattern further down in this module.
  """
  def build_api_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{token: hashed_token, context: "api", user_id: user.id}}
  end

  @doc """
  Checks if the API token is valid and returns its underlying lookup query.

  Accepts the URL-safe base64 encoded token (what the client sends in the
  Authorization header). Decodes, hashes, and looks up the stored hash with an
  `ago(@api_token_validity_in_days, "day")` window. Returns `:error` on
  malformed input.
  """
  def verify_api_token_query(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "api"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(@api_token_validity_in_days, "day"),
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  def verify_api_token_query(_), do: :error

  @doc """
  Returns the query that deletes an API token row given its encoded form.
  Decodes + hashes the input; returns `:error` on malformed input.
  """
  def delete_api_token_query(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        {:ok, from(t in UserToken, where: t.token == ^hashed_token and t.context == "api")}

      :error ->
        :error
    end
  end

  def delete_api_token_query(_), do: :error

  @doc """
  Generates a refresh token for biometric login (W105).

  Same hash-at-rest + URL-safe base64 pattern as API tokens. Stored in the
  `refresh` context with a 60-day validity window. Biometric unlock
  exchanges this token for a fresh API bearer via
  `POST /api/v1/auth/biometric-exchange`. Password change deletes all
  refresh tokens through `update_user_and_delete_all_tokens`.
  """
  def build_refresh_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{token: hashed_token, context: "refresh", user_id: user.id}}
  end

  @doc """
  Verifies a refresh token. Accepts the encoded form; decodes, hashes, looks
  up the row, and enforces the 60-day validity window. Returns the user
  query or `:error` on malformed input.
  """
  def verify_refresh_token_query(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "refresh"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(@refresh_token_validity_in_days, "day"),
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  def verify_refresh_token_query(_), do: :error

  @doc """
  Returns the query that deletes a refresh token row given its encoded form.
  """
  def delete_refresh_token_query(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        {:ok, from(t in UserToken, where: t.token == ^hashed_token and t.context == "refresh")}

      :error ->
        :error
    end
  end

  def delete_refresh_token_query(_), do: :error

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any, along with the token's creation time.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{user | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  If found, the query returns a tuple of the form `{user, token}`.

  The given token is valid if it matches its hashed counterpart in the
  database. This function also checks if the token is being used within
  15 minutes. The context of a magic link token is always "login".
  """
  def verify_magic_link_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "login"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^@magic_link_validity_in_minutes, "minute"),
            where: token.sent_to == user.email,
            select: {user, token}

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user_token found by the token, if any.

  This is used to validate requests to change the user
  email.
  The given token is valid if it matches its hashed counterpart in the
  database and if it has not expired (after @change_email_validity_in_days).
  The context must always start with "change:".
  """
  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if the confirmation token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.
  Confirmation tokens are valid for #{@confirm_validity_in_days} days.
  """
  def verify_confirmation_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "confirm"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^@confirm_validity_in_days, "day"),
            where: token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns a query to find all tokens for a user with the given contexts.
  """
  def user_and_contexts_query(user_id, contexts) do
    from t in UserToken, where: t.user_id == ^user_id and t.context in ^contexts
  end

  defp by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end
end
