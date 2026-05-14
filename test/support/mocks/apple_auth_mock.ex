defmodule TraysSocial.Accounts.AppleAuthMock do
  @moduledoc """
  Mock Apple token verifier for tests.

  The optional `expected_audiences` argument matches the real
  `AppleAuth.do_verify/2` signature — the mock ignores it (tests don't
  exercise the aud-validation branch; they just want a known {:ok, claims}
  shape for happy-path tests).

  Nonce claim: every "valid_*" token returns a fixed nonce hash so tests
  can pass the matching raw nonce ("test_nonce_raw") and have the W104
  nonce-validation branch in `AppleAuth.verify_token/2` succeed. Tests
  that want to exercise nonce-mismatch failures use a different raw nonce.
  """

  # SHA-256(:lower hex) of "test_nonce_raw" — kept as a literal so callers
  # don't need to recompute. If you change this, recompute via:
  #   :crypto.hash(:sha256, "test_nonce_raw") |> Base.encode16(case: :lower)
  @test_nonce_hash "a1a785abf10c97d8b09449d3dce54033f84e9b25d9dd967dd656bcac96c3b29b"

  def test_nonce_raw, do: "test_nonce_raw"
  def test_nonce_hash, do: @test_nonce_hash

  def do_verify(identity_token, _expected_audiences \\ nil)

  def do_verify("valid_apple_token", _expected_audiences) do
    {:ok,
     %{
       "sub" => "apple_user_001",
       "email" => "apple@privaterelay.appleid.com",
       "nonce" => @test_nonce_hash
     }}
  end

  def do_verify("valid_apple_token_no_email", _expected_audiences) do
    {:ok, %{"sub" => "apple_user_002", "nonce" => @test_nonce_hash}}
  end

  def do_verify("existing_apple_token", _expected_audiences) do
    {:ok,
     %{
       "sub" => "existing_apple_user",
       "email" => "existing@apple.com",
       "nonce" => @test_nonce_hash
     }}
  end

  def do_verify("valid_apple_token_no_nonce", _expected_audiences) do
    # Used to exercise the "Apple JWT missing required nonce claim" rejection.
    {:ok, %{"sub" => "apple_user_003", "email" => "no-nonce@example.com"}}
  end

  def do_verify(_invalid, _expected_audiences) do
    {:error, :invalid_apple_token}
  end
end
