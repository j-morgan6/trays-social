defmodule TraysSocial.Accounts.AppleAuthMock do
  @moduledoc """
  Mock Apple token verifier for tests.
  """

  def do_verify("valid_apple_token") do
    {:ok, %{"sub" => "apple_user_001", "email" => "apple@privaterelay.appleid.com"}}
  end

  def do_verify("valid_apple_token_no_email") do
    {:ok, %{"sub" => "apple_user_002"}}
  end

  def do_verify("existing_apple_token") do
    {:ok, %{"sub" => "existing_apple_user", "email" => "existing@apple.com"}}
  end

  def do_verify(_invalid) do
    {:error, :invalid_apple_token}
  end
end
