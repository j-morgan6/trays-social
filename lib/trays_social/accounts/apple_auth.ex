defmodule TraysSocial.Accounts.AppleAuth do
  @moduledoc """
  Handles Apple Sign In token verification.

  Verifies Apple identity tokens (JWTs) against Apple's public keys.
  In test, can be mocked via application config.
  """

  @apple_jwks_url "https://appleid.apple.com/auth/keys"

  @doc """
  Verifies an Apple identity token and returns the claims.

  Returns `{:ok, claims}` with at minimum `sub` (Apple's stable user ID)
  and optionally `email`.
  """
  def verify_token(identity_token) do
    verifier = Application.get_env(:trays_social, :apple_token_verifier, __MODULE__)
    verifier.do_verify(identity_token)
  end

  @doc false
  def do_verify(identity_token) do
    with {:ok, jwks} <- fetch_apple_public_keys(),
         {:ok, claims} <- verify_jwt(identity_token, jwks) do
      {:ok, claims}
    end
  end

  defp fetch_apple_public_keys do
    case Req.get(@apple_jwks_url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      _ -> {:error, :apple_keys_unavailable}
    end
  end

  defp verify_jwt(token, jwks) do
    case Assent.JWTAdapter.AssentJWT.verify(token, jwks["keys"], json_library: Jason) do
      {:ok, claims} -> {:ok, claims}
      {:error, _} -> {:error, :invalid_apple_token}
    end
  rescue
    _ -> {:error, :invalid_apple_token}
  end
end
