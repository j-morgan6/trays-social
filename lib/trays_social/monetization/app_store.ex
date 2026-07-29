defmodule TraysSocial.Monetization.AppStore do
  @moduledoc """
  App Store semantics for Trays Plus (W174): decodes signature-verified
  StoreKit 2 transactions and App Store Server Notifications V2, and applies
  Apple's business rules (bundle id, product allowlist, environment,
  expiry/revocation, notification-type mapping).

  Signature verification is delegated to
  `TraysSocial.Monetization.AppStore.JWS` — this module never touches crypto
  and never touches the database. Entitlement writes live in
  `TraysSocial.Monetization.Subscriptions`.

  Apple date fields are integer MILLISECONDS since the epoch.
  """

  alias TraysSocial.Monetization.AppStore.JWS

  require Logger

  @type transaction :: %{
          original_transaction_id: String.t(),
          transaction_id: String.t(),
          product_id: String.t(),
          environment: String.t(),
          expires_at: DateTime.t(),
          revoked?: boolean(),
          active?: boolean()
        }

  @type notification :: %{
          type: String.t(),
          subtype: String.t() | nil,
          uuid: String.t() | nil,
          transaction: transaction()
        }

  # Family Sharing is a legitimate entitlement; anything else (e.g. a
  # non-subscription ownership type) is not.
  @accepted_ownership_types ~w(PURCHASED FAMILY_SHARED)

  @grant_types ~w(SUBSCRIBED DID_RENEW OFFER_REDEEMED REFUND_REVERSED RENEWAL_EXTENDED)
  @revoke_types ~w(EXPIRED GRACE_PERIOD_EXPIRED REFUND REVOKE)

  @doc """
  Verifies a StoreKit 2 `jwsRepresentation` and returns the decoded transaction.
  """
  @spec verify_transaction(binary(), keyword()) :: {:ok, transaction()} | {:error, atom()}
  def verify_transaction(jws, opts \\ []) when is_binary(jws) do
    with {:ok, claims} <- JWS.verify(jws, opts),
         :ok <- check_bundle_id(claims["bundleId"]),
         :ok <- check_product_id(claims["productId"]),
         :ok <- check_environment(claims["environment"]),
         :ok <- check_ownership_type(claims["inAppOwnershipType"]) do
      build_transaction(claims)
    end
  end

  @doc """
  Verifies an App Store Server Notification V2 `signedPayload`, including the
  nested `signedTransactionInfo`, which is signed separately and MUST be
  verified in its own right.
  """
  @spec verify_notification(binary(), keyword()) :: {:ok, notification()} | {:error, atom()}
  def verify_notification(signed_payload, opts \\ []) when is_binary(signed_payload) do
    with {:ok, claims} <- JWS.verify(signed_payload, opts),
         {:ok, transaction} <- verify_notification_data(claims, opts) do
      {:ok,
       %{
         type: claims["notificationType"],
         subtype: claims["subtype"],
         uuid: claims["notificationUUID"],
         transaction: transaction
       }}
    end
  end

  # The nested signedTransactionInfo is signed separately from the envelope,
  # so it gets its own full verification pass — an attacker holding a valid
  # outer payload must not be able to smuggle an unsigned transaction inside.
  defp verify_notification_data(claims, opts) do
    with {:ok, data} <- fetch_data(claims),
         :ok <- check_bundle_id(data["bundleId"]),
         :ok <- check_environment(data["environment"]) do
      verify_transaction(data["signedTransactionInfo"] || "", opts)
    end
  end

  @doc """
  Maps a notification type (and subtype) to an entitlement action.

  Unknown types are `:ignore` — Apple adds notification types over time and an
  unrecognised one must never crash or flip entitlement. Types stay STRINGS
  end to end; converting them to atoms would be an atom-exhaustion vector.
  """
  @spec entitlement_for(String.t() | nil, String.t() | nil) :: :grant | :revoke | :ignore
  def entitlement_for(type, subtype \\ nil)

  # A failed renewal inside the billing grace period keeps the entitlement.
  def entitlement_for("DID_FAIL_TO_RENEW", "GRACE_PERIOD"), do: :grant
  def entitlement_for("DID_FAIL_TO_RENEW", _subtype), do: :ignore

  def entitlement_for(type, _subtype) when type in @grant_types, do: :grant
  def entitlement_for(type, _subtype) when type in @revoke_types, do: :revoke
  def entitlement_for(_type, _subtype), do: :ignore

  defp fetch_data(%{"data" => %{} = data}), do: {:ok, data}

  defp fetch_data(_claims) do
    Logger.warning("app store notification: payload has no data object")
    {:error, :malformed_notification}
  end

  defp check_bundle_id(bundle_id) do
    if bundle_id == expected_bundle_id() do
      :ok
    else
      Logger.warning("app store: bundle id mismatch")
      {:error, :bundle_id_mismatch}
    end
  end

  defp check_product_id(product_id) do
    if product_id in product_ids() do
      :ok
    else
      Logger.warning("app store: unknown product id")
      {:error, :unknown_product}
    end
  end

  defp check_environment(environment) do
    if environment in environments() do
      :ok
    else
      Logger.warning("app store: environment not accepted")
      {:error, :environment_mismatch}
    end
  end

  defp check_ownership_type(ownership_type) do
    if ownership_type in @accepted_ownership_types do
      :ok
    else
      Logger.warning("app store: unaccepted inAppOwnershipType")
      {:error, :malformed_transaction}
    end
  end

  # Fail closed on a missing expiry: an auto-renewable subscription always
  # carries expiresDate, and treating "no expiry" as "entitled forever" would
  # turn a malformed payload into a free lifetime subscription.
  defp build_transaction(claims) do
    with {:ok, expires_at} <- parse_ms(claims["expiresDate"]),
         {:ok, original_transaction_id} <- fetch_string(claims, "originalTransactionId") do
      revoked? = not is_nil(claims["revocationDate"])

      {:ok,
       %{
         original_transaction_id: original_transaction_id,
         transaction_id: to_string(claims["transactionId"] || ""),
         product_id: claims["productId"],
         environment: claims["environment"],
         expires_at: expires_at,
         revoked?: revoked?,
         active?: not revoked? and DateTime.after?(expires_at, DateTime.utc_now())
       }}
    end
  end

  defp parse_ms(ms) when is_integer(ms) do
    case DateTime.from_unix(ms, :millisecond) do
      {:ok, datetime} -> {:ok, datetime}
      {:error, _reason} -> malformed_transaction("expiresDate out of range")
    end
  end

  defp parse_ms(_other), do: malformed_transaction("expiresDate missing or not an integer")

  defp fetch_string(claims, key) do
    case claims[key] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> malformed_transaction("#{key} missing or not a string")
    end
  end

  defp malformed_transaction(reason) do
    Logger.warning("app store: malformed transaction (#{reason})")
    {:error, :malformed_transaction}
  end

  defp expected_bundle_id do
    Application.get_env(:trays_social, :apple_bundle_id, "com.trays.social")
  end

  defp app_store_config do
    Application.get_env(:trays_social, :app_store, [])
  end

  defp product_ids do
    Keyword.get(app_store_config(), :product_ids, [])
  end

  defp environments do
    Keyword.get(app_store_config(), :environments, ["Production"])
  end
end
