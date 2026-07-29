defmodule TraysSocial.AppStoreFixtures do
  @moduledoc """
  Generates real ES256 certificate chains and signed JWS payloads for the
  W174 App Store tests.

  Nothing is checked in and no network is touched: `:public_key.pkix_test_data/1`
  builds a fresh root -> intermediate -> leaf chain per call (~4ms), shaped like
  Apple's real chain (P-384 root and intermediate, P-256/ES256 leaf).

  Generated certs are valid for roughly 8 days from generation, which is
  exactly why they must never be committed — they are made at test runtime.
  The leaf also carries a SAN of the local hostname; harmless and unused.
  """

  @doc """
  Generates a fresh certificate chain.

  Returns `%{root_der:, intermediate_der:, leaf_der:, leaf_jwk:}`.
  """
  def cert_chain(opts \\ []) do
    peer =
      case Keyword.get(opts, :validity) do
        nil -> [{:key, {:namedCurve, :secp256r1}}, {:digest, :sha256}]
        validity -> [{:key, {:namedCurve, :secp256r1}}, {:digest, :sha256}, {:validity, validity}]
      end

    data =
      :public_key.pkix_test_data(%{
        root: [{:key, {:namedCurve, :secp384r1}}, {:digest, :sha384}],
        intermediates: [[{:key, {:namedCurve, :secp384r1}}, {:digest, :sha384}]],
        peer: peer
      })

    # GOTCHA: cacerts has THREE entries and the root appears twice —
    # [root, intermediate, root]. Filtering by self-signed is safer than
    # positional destructuring.
    cacerts = Keyword.fetch!(data, :cacerts)
    root_der = Enum.find(cacerts, &:public_key.pkix_is_self_signed/1)
    intermediate_der = Enum.find(cacerts, &(not :public_key.pkix_is_self_signed(&1)))

    %{
      root_der: root_der,
      intermediate_der: intermediate_der,
      leaf_der: Keyword.fetch!(data, :cert),
      leaf_jwk: private_jwk(data)
    }
  end

  # GOTCHA: data[:key] is the ssl-options tuple {:ECPrivateKey, der}, NOT an
  # ECPrivateKey record. JOSE.JWK.from_key/1 raises FunctionClauseError on it.
  defp private_jwk(data) do
    {:ECPrivateKey, priv_der} = Keyword.fetch!(data, :key)

    priv_der
    |> then(&:public_key.der_decode(:ECPrivateKey, &1))
    |> JOSE.JWK.from_key()
  end

  @doc """
  Signs `claims` with the chain's leaf key, populating the `x5c` header
  leaf-first exactly as Apple does.

  Pass `x5c: [...]` in `opts` to craft a deliberately malformed chain.
  """
  def sign_jws(chain, claims, opts \\ []) do
    x5c =
      Keyword.get_lazy(opts, :x5c, fn ->
        Enum.map([chain.leaf_der, chain.intermediate_der, chain.root_der], &Base.encode64/1)
      end)

    alg = Keyword.get(opts, :alg, "ES256")

    {_meta, compact} =
      chain.leaf_jwk
      |> JOSE.JWS.sign(Jason.encode!(claims), %{"alg" => alg, "x5c" => x5c})
      |> JOSE.JWS.compact()

    compact
  end

  @doc """
  A JWSTransactionDecodedPayload. Apple dates are integer MILLISECONDS.
  """
  def transaction_claims(overrides \\ %{}) do
    now_ms = System.system_time(:millisecond)

    Map.merge(
      %{
        "bundleId" => "com.trays.social",
        "productId" => "trays.plus.monthly",
        "originalTransactionId" => "2000000#{System.unique_integer([:positive])}",
        "transactionId" => "3000000#{System.unique_integer([:positive])}",
        "environment" => "Sandbox",
        "inAppOwnershipType" => "PURCHASED",
        "expiresDate" => now_ms + 30 * 24 * 60 * 60 * 1000,
        "purchaseDate" => now_ms
      },
      overrides
    )
  end

  @doc """
  An App Store Server Notification V2 payload with a nested, separately
  signed `signedTransactionInfo`.

  Pass `transaction_chain:` in `opts` to sign the nested transaction with a
  DIFFERENT chain — that is how the "outer payload valid, inner forged" case
  is exercised.
  """
  def notification_claims(chain, type, opts \\ []) do
    transaction_chain = Keyword.get(opts, :transaction_chain, chain)

    data =
      %{
        "bundleId" => Keyword.get(opts, :bundle_id, "com.trays.social"),
        "environment" => Keyword.get(opts, :environment, "Sandbox")
      }
      |> maybe_put_transaction(transaction_chain, opts)

    %{
      "notificationType" => type,
      "subtype" => Keyword.get(opts, :subtype),
      "notificationUUID" => "uuid-#{System.unique_integer([:positive])}",
      "version" => "2.0",
      "signedDate" => System.system_time(:millisecond),
      Keyword.get(opts, :envelope_key, "data") => data
    }
  end

  # Pass `transaction: :none` to model Apple's real TEST notification, whose
  # data object carries NO signedTransactionInfo. The default fixture attaches
  # one, which is more generous than Apple's actual payload — that gap once
  # hid a bug where transaction-less notifications were answered 401.
  defp maybe_put_transaction(data, chain, opts) do
    case Keyword.get(opts, :transaction, %{}) do
      :none ->
        data

      overrides ->
        Map.put(data, "signedTransactionInfo", sign_jws(chain, transaction_claims(overrides)))
    end
  end

  @doc """
  Points App Store verification at this chain's root for the duration of the
  test, restoring the previous value on exit.

  Tests using this MUST be `async: false`.
  """
  def with_trust_anchor(chain) do
    previous = Application.get_env(:trays_social, :app_store_root_certs)
    Application.put_env(:trays_social, :app_store_root_certs, [chain.root_der])

    ExUnit.Callbacks.on_exit(fn ->
      if previous do
        Application.put_env(:trays_social, :app_store_root_certs, previous)
      else
        Application.delete_env(:trays_social, :app_store_root_certs)
      end
    end)

    chain
  end
end
