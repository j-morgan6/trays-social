defmodule TraysSocial.Accounts.AppleAuthMock do
  @moduledoc """
  Mock Apple token verifier for tests.

  The optional `expected_audiences` argument matches the real
  `AppleAuth.do_verify/2` signature — the mock ignores it (tests don't
  exercise the aud-validation branch; they just want a known {:ok, claims}
  shape for happy-path tests).
  """

  def do_verify(identity_token, _expected_audiences \\ nil)

  def do_verify("valid_apple_token", _expected_audiences) do
    {:ok, %{"sub" => "apple_user_001", "email" => "apple@privaterelay.appleid.com"}}
  end

  def do_verify("valid_apple_token_no_email", _expected_audiences) do
    {:ok, %{"sub" => "apple_user_002"}}
  end

  def do_verify("existing_apple_token", _expected_audiences) do
    {:ok, %{"sub" => "existing_apple_user", "email" => "existing@apple.com"}}
  end

  def do_verify(_invalid, _expected_audiences) do
    {:error, :invalid_apple_token}
  end
end
