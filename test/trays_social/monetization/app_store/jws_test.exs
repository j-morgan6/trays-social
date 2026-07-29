defmodule TraysSocial.Monetization.AppStore.JWSTest do
  # async: true is safe because every test injects its anchors via the
  # `:trust_anchors` option rather than Application config.
  use ExUnit.Case, async: true

  alias TraysSocial.AppStoreFixtures
  alias TraysSocial.Monetization.AppStore.JWS

  setup do
    %{chain: AppStoreFixtures.cert_chain()}
  end

  defp verify(jws, chain), do: JWS.verify(jws, trust_anchors: [chain.root_der])

  describe "verify/2 happy path" do
    test "accepts a chain-signed JWS and returns the claims verbatim", %{chain: chain} do
      claims = AppStoreFixtures.transaction_claims()
      jws = AppStoreFixtures.sign_jws(chain, claims)

      assert {:ok, decoded} = verify(jws, chain)
      assert decoded == claims
    end

    test "round-trips the originalTransactionId with no added encoding layer", %{chain: chain} do
      # Guards the build-15 Apple Sign In double-encode class of bug: the id
      # that comes out must be byte-identical to the one that was signed.
      claims =
        AppStoreFixtures.transaction_claims(%{"originalTransactionId" => "2000000012345678"})

      jws = AppStoreFixtures.sign_jws(chain, claims)

      assert {:ok, %{"originalTransactionId" => "2000000012345678"}} = verify(jws, chain)
    end
  end

  describe "verify/2 rejects untrusted chains" do
    test "a chain signed by a different root", %{chain: chain} do
      foreign = AppStoreFixtures.cert_chain()
      jws = AppStoreFixtures.sign_jws(foreign, AppStoreFixtures.transaction_claims())

      assert {:error, :untrusted_certificate_chain} = verify(jws, chain)
    end

    test "leaf-only x5c is rejected, NOT validated against the root key", %{chain: chain} do
      # SECURITY: pkix_path_validation(Root, [], []) returns {:ok, ...} with
      # the ROOT's public key. A leaf-only x5c must never reach it.
      jws =
        AppStoreFixtures.sign_jws(chain, AppStoreFixtures.transaction_claims(),
          x5c: [Base.encode64(chain.leaf_der)]
        )

      assert {:error, :invalid_certificate_chain} = verify(jws, chain)
    end

    test "leaf plus an attacker's self-signed root is rejected", %{chain: chain} do
      attacker = AppStoreFixtures.cert_chain()

      jws =
        AppStoreFixtures.sign_jws(attacker, AppStoreFixtures.transaction_claims(),
          x5c: [Base.encode64(attacker.leaf_der), Base.encode64(attacker.root_der)]
        )

      assert {:error, :invalid_certificate_chain} = verify(jws, chain)
    end

    test "an entirely self-signed x5c collapses to an empty path", %{chain: chain} do
      attacker = AppStoreFixtures.cert_chain()

      jws =
        AppStoreFixtures.sign_jws(attacker, AppStoreFixtures.transaction_claims(),
          x5c: [Base.encode64(attacker.root_der)]
        )

      assert {:error, :invalid_certificate_chain} = verify(jws, chain)
    end
  end

  describe "verify/2 rejects malformed input" do
    test "garbage strings", %{chain: chain} do
      for junk <- ["not.a.jws", "", "aaaa", "a.b.c"] do
        assert {:error, reason} = verify(junk, chain)
        assert reason in [:malformed_jws, :invalid_certificate_chain]
      end
    end

    test "a JWS with no x5c header", %{chain: chain} do
      {_meta, jws} =
        chain.leaf_jwk
        |> JOSE.JWS.sign(Jason.encode!(%{"a" => 1}), %{"alg" => "ES256"})
        |> JOSE.JWS.compact()

      assert {:error, :invalid_certificate_chain} = verify(jws, chain)
    end

    test "an x5c entry that is not valid base64", %{chain: chain} do
      jws =
        AppStoreFixtures.sign_jws(chain, AppStoreFixtures.transaction_claims(),
          x5c: ["!!!not base64!!!", Base.encode64(chain.intermediate_der)]
        )

      assert {:error, :invalid_certificate_chain} = verify(jws, chain)
    end

    test "an oversized x5c is rejected before any cert parsing", %{chain: chain} do
      oversized = chain.leaf_der |> Base.encode64() |> List.duplicate(6)

      jws =
        AppStoreFixtures.sign_jws(chain, AppStoreFixtures.transaction_claims(), x5c: oversized)

      assert {:error, :invalid_certificate_chain} = verify(jws, chain)
    end
  end

  describe "verify/2 rejects tampering" do
    test "a mutated signature segment", %{chain: chain} do
      jws = AppStoreFixtures.sign_jws(chain, AppStoreFixtures.transaction_claims())
      [header, payload, signature] = String.split(jws, ".")
      tampered = Enum.join([header, payload, flip_first_char(signature)], ".")

      assert {:error, :invalid_signature} = verify(tampered, chain)
    end

    test "a mutated payload segment", %{chain: chain} do
      jws = AppStoreFixtures.sign_jws(chain, AppStoreFixtures.transaction_claims())
      [header, payload, signature] = String.split(jws, ".")
      tampered = Enum.join([header, flip_first_char(payload), signature], ".")

      assert {:error, :invalid_signature} = verify(tampered, chain)
    end

    test "alg confusion: a non-ES256 signature is refused", %{chain: chain} do
      # verify_strict pins the algorithm list, so an HS256 JWS carrying a
      # valid-looking x5c cannot be accepted.
      hmac_jwk = JOSE.JWK.from_oct("shared secret")

      x5c =
        Enum.map([chain.leaf_der, chain.intermediate_der, chain.root_der], &Base.encode64/1)

      {_meta, jws} =
        hmac_jwk
        |> JOSE.JWS.sign(Jason.encode!(%{"a" => 1}), %{"alg" => "HS256", "x5c" => x5c})
        |> JOSE.JWS.compact()

      assert {:error, :invalid_signature} = verify(jws, chain)
    end
  end

  describe "trust_anchors/0" do
    test "defaults to the pinned Apple root when no override is configured" do
      # config/test.exs deliberately leaves :app_store_root_certs unset so a
      # test that forgets to inject a chain fails closed.
      assert [root] = JWS.trust_anchors()
      assert byte_size(root) == 583

      digest = :sha256 |> :crypto.hash(root) |> Base.encode16(case: :lower)
      assert digest == "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"
    end
  end

  # Tamper with the FIRST character, never the last. A P-256 signature is 64
  # bytes, which base64url-encodes to 86 chars whose final character carries 4
  # unused bits — flipping it can decode to a byte-identical signature and the
  # assertion then fails intermittently. The first character always maps to
  # significant bits.
  defp flip_first_char(segment) do
    {first, tail} = String.split_at(segment, 1)
    replacement = if first == "A", do: "B", else: "A"
    replacement <> tail
  end
end
