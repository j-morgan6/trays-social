defmodule TraysSocial.Accounts.AppleAuth do
  @moduledoc """
  Handles Apple Sign In token verification.

  Verifies Apple identity tokens (JWTs) against Apple's published public keys
  (JWKs). Validates the signature plus the standard `iss`, `aud`, and `exp`
  claims so we don't accept tokens issued for any other Apple Sign In client.

  In test, the verifier can be swapped via `:apple_token_verifier` application
  config so fixtures don't need to construct real Apple-signed tokens.
  """

  require Logger

  @apple_jwks_url "https://appleid.apple.com/auth/keys"
  @apple_issuer "https://appleid.apple.com"

  @doc """
  Verifies an Apple identity token and returns the claims.

  Returns `{:ok, claims}` with at minimum `sub` (Apple's stable user ID)
  and optionally `email`.

  ## Options

    * `:expected_audiences` — list of acceptable `aud` claim values. iOS uses
      the App ID (e.g. `"com.trays.social"`); web Sign in with Apple uses a
      separate Services ID (e.g. `"com.trays.social.web"`). Pass both to
      accept tokens from either platform with a single call. Defaults to the
      iOS App ID from `:apple_bundle_id` config so existing callers don't
      have to change.

    * `:expected_nonce_hash` — the SHA-256 hex digest of the raw per-sign-in
      nonce the client sent to Apple. When provided, the JWT's `nonce` claim
      MUST equal this value (constant-time compare). Required for the iOS
      flow (W104). The web flow does not pass this — it uses a signed-state
      cookie for replay protection instead — so the option defaults to `nil`
      and nonce validation is skipped when absent.
  """
  def verify_token(identity_token, opts \\ []) do
    expected_audiences = Keyword.get(opts, :expected_audiences, [expected_bundle_id()])
    expected_nonce_hash = Keyword.get(opts, :expected_nonce_hash)
    verifier = Application.get_env(:trays_social, :apple_token_verifier, __MODULE__)

    with {:ok, claims} <- verifier.do_verify(identity_token, expected_audiences),
         :ok <- validate_nonce(claims, expected_nonce_hash) do
      {:ok, claims}
    end
  end

  # When the caller does not pass `:expected_nonce_hash`, nonce validation is
  # skipped entirely. Web flow uses this branch.
  defp validate_nonce(_claims, nil), do: :ok

  defp validate_nonce(claims, expected_hash) when is_binary(expected_hash) do
    case claims["nonce"] do
      nil ->
        Logger.warning("Apple JWT missing required nonce claim")
        {:error, :invalid_apple_token}

      actual when is_binary(actual) ->
        if Plug.Crypto.secure_compare(actual, expected_hash) do
          :ok
        else
          Logger.warning("Apple JWT nonce mismatch (possible replay)")
          {:error, :invalid_apple_token}
        end

      _ ->
        Logger.warning("Apple JWT nonce claim is not a string")
        {:error, :invalid_apple_token}
    end
  end

  @doc false
  def do_verify(identity_token, expected_audiences \\ nil) do
    expected_audiences = expected_audiences || [expected_bundle_id()]

    with {:ok, jwks} <- fetch_apple_public_keys(),
         {:ok, header} <- peek_header(identity_token),
         {:ok, jwk} <- find_jwk(jwks, header["kid"]),
         {:ok, claims} <- verify_signature(jwk, identity_token),
         :ok <- validate_claims(claims, expected_audiences) do
      {:ok, claims}
    else
      {:error, :apple_keys_unavailable} = err ->
        err

      {:error, reason} = err ->
        Logger.warning("Apple identity token verification failed: #{inspect(reason)}")
        err
    end
  end

  defp fetch_apple_public_keys do
    case Req.get(@apple_jwks_url) do
      {:ok, %{status: 200, body: %{"keys" => keys}}} when is_list(keys) ->
        {:ok, keys}

      other ->
        Logger.warning("Apple JWKs fetch failed: #{inspect(other)}")
        {:error, :apple_keys_unavailable}
    end
  end

  defp peek_header(token) do
    try do
      %JOSE.JWS{fields: header} = JOSE.JWT.peek_protected(token)
      {:ok, header}
    rescue
      e ->
        Logger.warning("Apple JWT header peek failed: #{inspect(e)}")
        {:error, :invalid_apple_token}
    end
  end

  defp find_jwk(keys, kid) when is_binary(kid) do
    case Enum.find(keys, fn key -> key["kid"] == kid end) do
      nil ->
        Logger.warning("Apple JWT signed by unknown kid: #{inspect(kid)}")
        {:error, :invalid_apple_token}

      key ->
        {:ok, JOSE.JWK.from_map(key)}
    end
  end

  defp find_jwk(_keys, _kid), do: {:error, :invalid_apple_token}

  defp verify_signature(jwk, token) do
    try do
      case JOSE.JWT.verify_strict(jwk, ["RS256"], token) do
        {true, %JOSE.JWT{fields: claims}, _} ->
          {:ok, claims}

        {false, _, _} ->
          Logger.warning("Apple JWT signature verification returned false")
          {:error, :invalid_apple_token}

        other ->
          Logger.warning("Apple JWT verify_strict unexpected: #{inspect(other)}")
          {:error, :invalid_apple_token}
      end
    rescue
      e ->
        Logger.warning("Apple JWT verify_strict raised: #{inspect(e)}")
        {:error, :invalid_apple_token}
    end
  end

  defp validate_claims(claims, expected_audiences) do
    now = System.system_time(:second)

    cond do
      claims["iss"] != @apple_issuer ->
        Logger.warning("Apple JWT issuer mismatch: got #{inspect(claims["iss"])}")
        {:error, :invalid_apple_token}

      claims["aud"] not in expected_audiences ->
        Logger.warning(
          "Apple JWT audience mismatch: got #{inspect(claims["aud"])}, expected one of #{inspect(expected_audiences)}"
        )

        {:error, :invalid_apple_token}

      is_integer(claims["exp"]) and claims["exp"] < now ->
        Logger.warning("Apple JWT expired: exp=#{claims["exp"]} now=#{now}")
        {:error, :invalid_apple_token}

      true ->
        :ok
    end
  end

  defp expected_bundle_id do
    Application.get_env(:trays_social, :apple_bundle_id, "com.trays.social")
  end
end
