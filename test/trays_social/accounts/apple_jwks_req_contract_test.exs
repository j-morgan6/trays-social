defmodule TraysSocial.Accounts.AppleJwksReqContractTest do
  # Pins the Req defaults that AppleAuth.fetch_apple_public_keys/0
  # (lib/trays_social/accounts/apple_auth.ex) relies on: it calls
  # `Req.get(url)` with no options and pattern-matches the body as an already
  # decoded `%{"keys" => keys}` map. The rest of the suite mocks AppleAuth, so
  # without this test a Req bump that changed those defaults (W208 moved
  # 0.5 -> 0.6, where compression became opt-in) would pass CI and only break
  # Sign in with Apple in production.
  #
  # The request never leaves the VM: the `plug:` option routes it to a local
  # function standing in for Apple's JWKS endpoint.
  use ExUnit.Case, async: true

  @jwks %{"keys" => [%{"kty" => "RSA", "kid" => "test-kid", "use" => "sig", "alg" => "RS256"}]}

  defp apple_jwks_stub(test_pid) do
    fn conn ->
      send(test_pid, {:accept_encoding, Plug.Conn.get_req_header(conn, "accept-encoding")})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(@jwks))
    end
  end

  test "a JSON JWKS response is auto-decoded into the map AppleAuth matches on" do
    assert {:ok, %{status: 200, body: %{"keys" => keys}}} =
             Req.get("https://appleid.apple.test/auth/keys", plug: apple_jwks_stub(self()))

    assert [%{"kid" => "test-kid"}] = keys
  end

  test "no accept-encoding is sent, so the body cannot come back compressed" do
    Req.get!("https://appleid.apple.test/auth/keys", plug: apple_jwks_stub(self()))

    assert_received {:accept_encoding, []}
  end
end
