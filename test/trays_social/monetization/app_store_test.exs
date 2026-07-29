defmodule TraysSocial.Monetization.AppStoreTest do
  use ExUnit.Case, async: true

  alias TraysSocial.AppStoreFixtures
  alias TraysSocial.Monetization.AppStore

  setup do
    %{chain: AppStoreFixtures.cert_chain()}
  end

  defp verify(chain, overrides) do
    jws = AppStoreFixtures.sign_jws(chain, AppStoreFixtures.transaction_claims(overrides))
    AppStore.verify_transaction(jws, trust_anchors: [chain.root_der])
  end

  describe "verify_transaction/2 allowlists" do
    test "rejects a wrong bundle id", %{chain: chain} do
      assert {:error, :bundle_id_mismatch} = verify(chain, %{"bundleId" => "com.evil.app"})
    end

    test "rejects a product id outside the allowlist", %{chain: chain} do
      assert {:error, :unknown_product} = verify(chain, %{"productId" => "trays.plus.lifetime"})
    end

    test "rejects an environment that is not configured", %{chain: chain} do
      # config/test.exs allows Sandbox only.
      assert {:error, :environment_mismatch} = verify(chain, %{"environment" => "Production"})
    end

    test "accepts both configured product ids", %{chain: chain} do
      assert {:ok, _} = verify(chain, %{"productId" => "trays.plus.monthly"})
      assert {:ok, _} = verify(chain, %{"productId" => "trays.plus.yearly"})
    end
  end

  describe "verify_transaction/2 ownership type" do
    test "accepts PURCHASED and FAMILY_SHARED", %{chain: chain} do
      assert {:ok, _} = verify(chain, %{"inAppOwnershipType" => "PURCHASED"})
      assert {:ok, _} = verify(chain, %{"inAppOwnershipType" => "FAMILY_SHARED"})
    end

    test "rejects anything else", %{chain: chain} do
      assert {:error, :malformed_transaction} =
               verify(chain, %{"inAppOwnershipType" => "NONSENSE"})
    end
  end

  describe "verify_transaction/2 active determination" do
    test "a future expiry is active", %{chain: chain} do
      future = System.system_time(:millisecond) + 60_000
      assert {:ok, %{active?: true, revoked?: false}} = verify(chain, %{"expiresDate" => future})
    end

    test "a past expiry is inactive", %{chain: chain} do
      past = System.system_time(:millisecond) - 60_000
      assert {:ok, %{active?: false}} = verify(chain, %{"expiresDate" => past})
    end

    test "a revocationDate makes it inactive even with a future expiry", %{chain: chain} do
      future = System.system_time(:millisecond) + 60_000

      assert {:ok, %{active?: false, revoked?: true}} =
               verify(chain, %{
                 "expiresDate" => future,
                 "revocationDate" => System.system_time(:millisecond)
               })
    end

    test "a missing expiresDate fails closed rather than meaning 'forever'", %{chain: chain} do
      assert {:error, :malformed_transaction} = verify(chain, %{"expiresDate" => nil})
    end

    test "a non-integer expiresDate is rejected", %{chain: chain} do
      assert {:error, :malformed_transaction} = verify(chain, %{"expiresDate" => "soon"})
    end

    test "a missing originalTransactionId is rejected", %{chain: chain} do
      assert {:error, :malformed_transaction} = verify(chain, %{"originalTransactionId" => nil})
    end
  end

  describe "entitlement_for/2" do
    test "grant types" do
      for type <- ~w(SUBSCRIBED DID_RENEW OFFER_REDEEMED REFUND_REVERSED RENEWAL_EXTENDED) do
        assert AppStore.entitlement_for(type) == :grant, "expected #{type} to grant"
      end
    end

    test "revoke types" do
      for type <- ~w(EXPIRED GRACE_PERIOD_EXPIRED REFUND REVOKE) do
        assert AppStore.entitlement_for(type) == :revoke, "expected #{type} to revoke"
      end
    end

    test "DID_FAIL_TO_RENEW grants only inside the grace period" do
      assert AppStore.entitlement_for("DID_FAIL_TO_RENEW", "GRACE_PERIOD") == :grant
      assert AppStore.entitlement_for("DID_FAIL_TO_RENEW", nil) == :ignore
    end

    test "informational types are ignored" do
      for type <- ~w(DID_CHANGE_RENEWAL_STATUS DID_CHANGE_RENEWAL_PREF PRICE_INCREASE TEST) do
        assert AppStore.entitlement_for(type) == :ignore, "expected #{type} to be ignored"
      end
    end

    test "an unknown future type is ignored, never a crash" do
      assert AppStore.entitlement_for("SOMETHING_APPLE_ADDS_IN_2027") == :ignore
      assert AppStore.entitlement_for(nil) == :ignore
    end
  end

  describe "verify_notification/2" do
    test "verifies the outer payload and the nested transaction", %{chain: chain} do
      payload =
        AppStoreFixtures.sign_jws(chain, AppStoreFixtures.notification_claims(chain, "DID_RENEW"))

      assert {:ok, notification} =
               AppStore.verify_notification(payload, trust_anchors: [chain.root_der])

      assert notification.type == "DID_RENEW"
      assert notification.transaction.active?
    end

    test "rejects a forged nested transaction even when the outer payload is valid", %{
      chain: chain
    } do
      # The nested signedTransactionInfo is signed separately, so it must be
      # verified in its own right — an attacker with a valid outer envelope
      # must not be able to smuggle an unsigned transaction inside it.
      foreign = AppStoreFixtures.cert_chain()

      claims =
        AppStoreFixtures.notification_claims(chain, "DID_RENEW", transaction_chain: foreign)

      payload = AppStoreFixtures.sign_jws(chain, claims)

      assert {:error, :untrusted_certificate_chain} =
               AppStore.verify_notification(payload, trust_anchors: [chain.root_der])
    end

    test "rejects a payload with no data object", %{chain: chain} do
      payload = AppStoreFixtures.sign_jws(chain, %{"notificationType" => "DID_RENEW"})

      assert {:error, :malformed_notification} =
               AppStore.verify_notification(payload, trust_anchors: [chain.root_der])
    end

    test "rejects a foreign bundle id", %{chain: chain} do
      claims = AppStoreFixtures.notification_claims(chain, "DID_RENEW", bundle_id: "com.evil.app")
      payload = AppStoreFixtures.sign_jws(chain, claims)

      assert {:error, :bundle_id_mismatch} =
               AppStore.verify_notification(payload, trust_anchors: [chain.root_der])
    end
  end
end
