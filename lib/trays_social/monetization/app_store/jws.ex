defmodule TraysSocial.Monetization.AppStore.JWS do
  @moduledoc """
  Verifies App Store Server JWS payloads (StoreKit 2 signed transactions and
  App Store Server Notifications V2) against a pinned Apple root certificate.

  This module is crypto ONLY — no database access, no Apple business rules.
  Apple semantics (bundle id, product allowlist, entitlement mapping) live in
  `TraysSocial.Monetization.AppStore`.

  ## Why this is not `TraysSocial.Accounts.AppleAuth`

  Sign in with Apple uses a JWKS `kid` lookup over the network and RS256.
  App Store Server JWS is **self-contained**: the signing certificate chain
  travels in the `x5c` JOSE header and the algorithm is ES256. There is no
  network fetch here at all — which is also why verification works identically
  in Sandbox and Production.

  ## The trust model

  The chain that arrives in `x5c` is attacker-controlled. It is used only to
  build a candidate path; the trust anchor is always OUR pinned Apple root,
  never the root the caller supplied. Verification then uses the public key
  that path validation returns, so it is structurally impossible to verify a
  signature against a key that was not chain-validated first.
  """

  require Logger

  @priv_dir :code.priv_dir(:trays_social)
  @root_cert_path Path.join(@priv_dir, "certs/AppleRootCA-G3.cer")
  @external_resource @root_cert_path

  @apple_root_g3 File.read!(@root_cert_path)
  @apple_root_g3_sha256 "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"

  # Compile-time pin: a swapped or corrupted root cert fails the BUILD rather
  # than silently trusting the wrong authority in production. The intermediate
  # attribute is required — credo's NestedFunctionCalls rejects the one-liner.
  @computed_root_sha :sha256 |> :crypto.hash(@apple_root_g3) |> Base.encode16(case: :lower)

  if @computed_root_sha != @apple_root_g3_sha256 do
    raise """
    priv/certs/AppleRootCA-G3.cer does not match the pinned SHA-256.
      expected: #{@apple_root_g3_sha256}
      actual:   #{@computed_root_sha}
    Re-fetch from https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
    """
  end

  # An Apple chain is [leaf, intermediate, root]. Cap the list so a crafted
  # 10_000-entry x5c cannot burn CPU in pkix_is_self_signed/1.
  @max_chain_length 5

  @type error ::
          :malformed_jws
          | :invalid_certificate_chain
          | :untrusted_certificate_chain
          | :invalid_signature

  @doc """
  Verifies a compact JWS and returns its decoded claims.

  Options:

    * `:trust_anchors` — list of DER-encoded root certificates to validate
      against. Defaults to the pinned Apple Root CA - G3. Tests inject a
      locally generated root here so no network or checked-in fixture is
      needed.

  Every error is deliberately coarse. Telling a caller *which* stage of
  verification failed is a free oracle; the specific reason is logged at
  warning level and never returned.
  """
  @spec verify(binary(), keyword()) :: {:ok, map()} | {:error, error()}
  def verify(jws, opts \\ []) when is_binary(jws) do
    anchors = Keyword.get_lazy(opts, :trust_anchors, &trust_anchors/0)

    with {:ok, x5c} <- peek_x5c(jws),
         {:ok, path} <- build_path(x5c),
         {:ok, leaf_key} <- validate_path(path, anchors) do
      verify_signature(leaf_key, jws)
    end
  end

  @doc """
  The DER-encoded trust anchors used for verification.

  Returns the pinned Apple root unless `:app_store_root_certs` is configured.
  That key is deliberately test-only and has NO runtime.exs / env-var binding —
  an operator-settable trust anchor would let one `fly secrets set` disable
  certificate pinning entirely.
  """
  @spec trust_anchors() :: [binary()]
  def trust_anchors do
    case Application.get_env(:trays_social, :app_store_root_certs) do
      certs when is_list(certs) and certs != [] -> certs
      _ -> [@apple_root_g3]
    end
  end

  defp peek_x5c(jws) do
    %JOSE.JWS{fields: fields} = JOSE.JWT.peek_protected(jws)

    # Note: "alg" is NOT in `fields` — it lives on the %JOSE.JWS{} struct.
    # A single-element x5c is rejected here AND by the length guard below.
    case fields["x5c"] do
      [_, _ | _] = x5c when length(x5c) <= @max_chain_length ->
        {:ok, x5c}

      _ ->
        Logger.warning("app store jws: missing, short, or oversized x5c header")
        {:error, :invalid_certificate_chain}
    end
  rescue
    _ ->
      Logger.warning("app store jws: header could not be parsed")
      {:error, :malformed_jws}
  end

  # x5c entries are STANDARD base64 with padding (RFC 7515), not base64url.
  defp build_path(x5c) do
    ders = Enum.map(x5c, &decode_cert/1)

    if Enum.any?(ders, &(&1 == :error)) do
      Logger.warning("app store jws: x5c entry is not valid base64")
      {:error, :invalid_certificate_chain}
    else
      ders |> reject_self_signed() |> order_path()
    end
  end

  defp decode_cert(entry) when is_binary(entry) do
    case Base.decode64(entry) do
      {:ok, der} -> der
      :error -> :error
    end
  end

  defp decode_cert(_entry), do: :error

  # Drop ANY self-signed cert rather than "drop the last element". A forged
  # x5c of [leaf, attacker_self_signed_root] therefore collapses to a
  # one-element path and is rejected by the length guard below.
  defp reject_self_signed(ders) do
    Enum.reject(ders, &self_signed?/1)
  end

  # An unparseable cert is treated as self-signed so it is dropped from the
  # path rather than handed to pkix_path_validation — fail closed.
  defp self_signed?(der) do
    :public_key.pkix_is_self_signed(der)
  rescue
    _ -> true
  end

  # pkix_path_validation/3 wants the path ordered from the anchor's immediate
  # child down to the peer; Apple sends leaf-first, so reverse.
  #
  # SECURITY — the length guard is load-bearing, do NOT remove it as
  # over-engineering: :public_key.pkix_path_validation(Root, [], []) returns
  # {:ok, ...} carrying the ROOT's public key. An empty or single-element path
  # would therefore "validate" and hand back Apple's root key to verify
  # against. Requiring >= 2 keeps a real intermediate + leaf in the path.
  defp order_path(path) do
    case Enum.reverse(path) do
      [_, _ | _] = ordered ->
        {:ok, ordered}

      _ ->
        Logger.warning("app store jws: certificate path too short after filtering")
        {:error, :invalid_certificate_chain}
    end
  end

  defp validate_path(path, anchors) do
    Enum.reduce_while(anchors, {:error, :untrusted_certificate_chain}, fn anchor, acc ->
      case safe_path_validation(anchor, path) do
        {:ok, {{_alg_oid, public_key, params}, _policy_tree}} ->
          {:halt, {:ok, {public_key, params}}}

        {:error, _reason} ->
          {:cont, acc}
      end
    end)
    |> tap(fn
      {:error, :untrusted_certificate_chain} ->
        Logger.warning("app store jws: chain did not validate to any trusted anchor")

      _ ->
        :ok
    end)
  end

  defp safe_path_validation(anchor, path) do
    :public_key.pkix_path_validation(anchor, path, [])
  rescue
    _ -> {:error, :malformed_certificate}
  end

  # Uses the public key RETURNED BY path validation — never a key re-decoded
  # from the caller's leaf — so an unvalidated key can never reach verify.
  # verify_strict with an explicit alg list is what blocks alg-confusion;
  # JOSE.JWT.verify/2 would honour the attacker's "alg" header.
  defp verify_signature(leaf_key, jws) do
    jwk = JOSE.JWK.from_key(leaf_key)

    case JOSE.JWT.verify_strict(jwk, ["ES256"], jws) do
      {true, %JOSE.JWT{fields: claims}, _jws} ->
        {:ok, claims}

      _ ->
        Logger.warning("app store jws: signature did not verify")
        {:error, :invalid_signature}
    end
  rescue
    _ ->
      Logger.warning("app store jws: signature verification raised")
      {:error, :invalid_signature}
  end
end
