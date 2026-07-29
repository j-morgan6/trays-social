defmodule TraysSocialWeb.Webhooks.AppStoreControllerTest do
  # async: false — swaps the global :app_store_root_certs anchor.
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.AppStoreFixtures

  @oti "2000000055555555"

  setup do
    chain = AppStoreFixtures.with_trust_anchor(AppStoreFixtures.cert_chain())
    user = user_fixture()
    {:ok, user} = Accounts.set_apple_original_transaction_id(user, @oti)
    %{chain: chain, user: user}
  end

  defp notify(conn, chain, type, opts \\ []) do
    opts = Keyword.put_new(opts, :transaction, %{"originalTransactionId" => @oti})
    claims = AppStoreFixtures.notification_claims(chain, type, opts)
    payload = AppStoreFixtures.sign_jws(chain, claims)
    post(conn, ~p"/webhooks/app-store", %{"signedPayload" => payload})
  end

  defp reload(user), do: Accounts.get_user!(user.id)

  describe "entitlement mapping" do
    test "DID_RENEW grants", %{conn: conn, chain: chain, user: user} do
      assert response(notify(conn, chain, "DID_RENEW"), 200)
      assert reload(user).is_subscriber
    end

    test "SUBSCRIBED grants", %{conn: conn, chain: chain, user: user} do
      assert response(notify(conn, chain, "SUBSCRIBED"), 200)
      assert reload(user).is_subscriber
    end

    test "EXPIRED revokes", %{conn: conn, chain: chain, user: user} do
      {:ok, user} = Accounts.set_subscriber(user, true)
      assert response(notify(conn, chain, "EXPIRED"), 200)
      refute reload(user).is_subscriber
    end

    test "REFUND and REVOKE revoke", %{conn: conn, chain: chain, user: user} do
      for type <- ["REFUND", "REVOKE"] do
        {:ok, _} = Accounts.set_subscriber(user, true)
        assert response(notify(conn, chain, type), 200)
        refute reload(user).is_subscriber
      end
    end
  end

  describe "acks without changing entitlement" do
    test "a TEST notification", %{conn: conn, chain: chain, user: user} do
      assert response(notify(conn, chain, "TEST"), 200)
      refute reload(user).is_subscriber
    end

    test "an unknown future notification type does not crash", %{
      conn: conn,
      chain: chain,
      user: user
    } do
      assert response(notify(conn, chain, "SOMETHING_APPLE_ADDS_IN_2027"), 200)
      refute reload(user).is_subscriber
    end

    test "DID_CHANGE_RENEWAL_STATUS is informational", %{conn: conn, chain: chain, user: user} do
      {:ok, user} = Accounts.set_subscriber(user, true)
      assert response(notify(conn, chain, "DID_CHANGE_RENEWAL_STATUS"), 200)
      assert reload(user).is_subscriber
    end

    test "a transaction no user holds", %{conn: conn, chain: chain} do
      assert response(
               notify(conn, chain, "DID_RENEW",
                 transaction: %{"originalTransactionId" => "2000000000000001"}
               ),
               200
             )
    end

    test "a foreign bundle id is acked so Apple stops retrying", %{
      conn: conn,
      chain: chain,
      user: user
    } do
      assert response(notify(conn, chain, "DID_RENEW", bundle_id: "com.evil.app"), 200)
      refute reload(user).is_subscriber
    end

    test "an environment we do not accept is acked", %{conn: conn, chain: chain, user: user} do
      assert response(notify(conn, chain, "DID_RENEW", environment: "Production"), 200)
      refute reload(user).is_subscriber
    end
  end

  describe "signature rejection" do
    test "a payload signed by a foreign root is 401 with no write", %{
      conn: conn,
      user: user
    } do
      foreign = AppStoreFixtures.cert_chain()

      claims =
        AppStoreFixtures.notification_claims(foreign, "DID_RENEW",
          transaction: %{"originalTransactionId" => @oti}
        )

      payload = AppStoreFixtures.sign_jws(foreign, claims)

      assert response(post(conn, ~p"/webhooks/app-store", %{"signedPayload" => payload}), 401)
      refute reload(user).is_subscriber
    end

    test "a forged nested transaction is 401 even with a valid outer payload", %{
      conn: conn,
      chain: chain,
      user: user
    } do
      foreign = AppStoreFixtures.cert_chain()

      claims =
        AppStoreFixtures.notification_claims(chain, "DID_RENEW",
          transaction_chain: foreign,
          transaction: %{"originalTransactionId" => @oti}
        )

      payload = AppStoreFixtures.sign_jws(chain, claims)

      assert response(post(conn, ~p"/webhooks/app-store", %{"signedPayload" => payload}), 401)
      refute reload(user).is_subscriber
    end

    test "garbage and missing payloads", %{conn: conn} do
      assert response(post(conn, ~p"/webhooks/app-store", %{"signedPayload" => "junk"}), 401)
      assert response(post(conn, ~p"/webhooks/app-store", %{}), 400)
      assert response(post(conn, ~p"/webhooks/app-store", %{"signedPayload" => 12_345}), 400)
    end
  end

  describe "route configuration" do
    test "does NOT require user auth — Apple posts with no bearer token", %{chain: chain} do
      # The concrete assertion for "webhook route must not require user auth":
      # an unauthenticated request must be processed, not 401'd by AuthPlug.
      claims =
        AppStoreFixtures.notification_claims(chain, "DID_RENEW",
          transaction: %{"originalTransactionId" => @oti}
        )

      payload = AppStoreFixtures.sign_jws(chain, claims)

      conn = post(build_conn(), ~p"/webhooks/app-store", %{"signedPayload" => payload})
      assert response(conn, 200)
    end
  end
end
