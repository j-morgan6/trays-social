defmodule TraysSocialWeb.API.V1.SubscriptionControllerTest do
  # async: false — these tests swap the global :app_store_root_certs anchor.
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.AppStoreFixtures

  setup :register_and_api_authenticate_user

  setup do
    %{chain: AppStoreFixtures.with_trust_anchor(AppStoreFixtures.cert_chain())}
  end

  defp post_verify(conn, jws) do
    post(conn, ~p"/api/v1/subscriptions/verify", %{"jws" => jws})
  end

  defp signed(chain, overrides \\ %{}) do
    AppStoreFixtures.sign_jws(chain, AppStoreFixtures.transaction_claims(overrides))
  end

  defp reload(user), do: Accounts.get_user!(user.id)

  describe "successful verification" do
    test "grants entitlement and stamps the transaction id", %{
      conn: conn,
      user: user,
      chain: chain
    } do
      claims =
        AppStoreFixtures.transaction_claims(%{"originalTransactionId" => "2000000012345678"})

      jws = AppStoreFixtures.sign_jws(chain, claims)

      assert %{"data" => data} = json_response(post_verify(conn, jws), 200)
      assert data["is_subscriber"] == true
      assert data["product_id"] == "trays.plus.monthly"
      assert data["environment"] == "Sandbox"

      # Round-trip: the id we return and store must be byte-identical to the
      # one inside the signed payload — no extra encoding layer anywhere.
      # (Build 15 shipped a double-encoded bearer on the Apple auth path.)
      assert data["original_transaction_id"] == "2000000012345678"

      reloaded = reload(user)
      assert reloaded.is_subscriber
      assert reloaded.apple_original_transaction_id == "2000000012345678"
    end

    test "is idempotent when called twice with the same transaction", %{conn: conn, chain: chain} do
      jws = signed(chain)

      assert %{"data" => first} = json_response(post_verify(conn, jws), 200)
      assert %{"data" => second} = json_response(post_verify(conn, jws), 200)
      assert first == second
    end

    test "an expired transaction re-locks a currently-subscribed user", %{
      conn: conn,
      user: user,
      chain: chain
    } do
      {:ok, _} = Accounts.set_subscriber(user, true)
      past = System.system_time(:millisecond) - 60_000

      assert %{"data" => %{"is_subscriber" => false}} =
               json_response(post_verify(conn, signed(chain, %{"expiresDate" => past})), 200)

      refute reload(user).is_subscriber
    end
  end

  describe "rejections leave entitlement untouched" do
    setup %{user: user} do
      # Seed as a subscriber so "untouched" is a strictly stronger assertion
      # than merely checking the flag is false.
      {:ok, user} = Accounts.set_subscriber(user, true)
      %{user: user}
    end

    test "a chain signed by a foreign root", %{conn: conn, user: user} do
      foreign = AppStoreFixtures.cert_chain()
      jws = AppStoreFixtures.sign_jws(foreign, AppStoreFixtures.transaction_claims())

      assert %{"errors" => [%{"code" => "invalid_transaction"}]} =
               json_response(post_verify(conn, jws), 422)

      assert reload(user).is_subscriber
    end

    test "a wrong bundle id", %{conn: conn, user: user, chain: chain} do
      jws = signed(chain, %{"bundleId" => "com.evil.app"})

      assert %{"errors" => [%{"code" => "invalid_transaction"}]} =
               json_response(post_verify(conn, jws), 422)

      assert reload(user).is_subscriber
    end

    test "an unknown product", %{conn: conn, user: user, chain: chain} do
      jws = signed(chain, %{"productId" => "trays.plus.lifetime"})

      assert %{"errors" => [%{"code" => "unknown_product"}]} =
               json_response(post_verify(conn, jws), 422)

      assert reload(user).is_subscriber
    end

    test "a tampered signature", %{conn: conn, user: user, chain: chain} do
      [header, payload, signature] = chain |> signed() |> String.split(".")

      # Mutate the FIRST character, not the last: a P-256 signature's final
      # base64url character carries unused bits, so flipping it can decode to
      # a byte-identical signature and the assertion passes only sometimes.
      {first, tail} = String.split_at(signature, 1)
      flipped = if first == "A", do: "B", else: "A"
      tampered = Enum.join([header, payload, flipped <> tail], ".")

      assert %{"errors" => [%{"code" => "invalid_transaction"}]} =
               json_response(post_verify(conn, tampered), 422)

      assert reload(user).is_subscriber
    end
  end

  describe "malformed request bodies never 500" do
    test "a double-encoded jws is a clean 422", %{conn: conn, user: user, chain: chain} do
      # The exact build-15 failure shape: the client wraps the JWS in another
      # encoding layer instead of sending it raw.
      double_encoded = chain |> signed() |> Base.encode64()

      assert %{"errors" => [%{"code" => "invalid_transaction"}]} =
               json_response(post_verify(conn, double_encoded), 422)

      refute reload(user).is_subscriber
    end

    test "non-string and missing jws values", %{conn: conn} do
      for body <- [%{"jws" => 12_345}, %{"jws" => nil}, %{"jws" => %{"a" => 1}}, %{}] do
        conn = post(conn, ~p"/api/v1/subscriptions/verify", body)
        assert %{"errors" => [%{"code" => "invalid_transaction"}]} = json_response(conn, 422)
      end
    end
  end

  describe "collision with another account" do
    test "returns 409 and changes neither account", %{conn: conn, user: user, chain: chain} do
      other = user_fixture()

      claims =
        AppStoreFixtures.transaction_claims(%{"originalTransactionId" => "2000000099999999"})

      {:ok, other} = Accounts.set_apple_original_transaction_id(other, "2000000099999999")
      {:ok, other} = Accounts.set_subscriber(other, true)

      jws = AppStoreFixtures.sign_jws(chain, claims)

      assert %{"errors" => [%{"code" => "transaction_already_claimed"}]} =
               json_response(post_verify(conn, jws), 409)

      refute reload(user).is_subscriber
      assert is_nil(reload(user).apple_original_transaction_id)
      assert reload(other).is_subscriber
    end
  end

  describe "authentication" do
    test "requires a bearer token", %{chain: chain} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/subscriptions/verify", %{"jws" => signed(chain)})

      assert json_response(conn, 401)
    end
  end
end
