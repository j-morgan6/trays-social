defmodule TraysSocialWeb.API.V1.SubscriptionController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Monetization.AppStore
  alias TraysSocial.Monetization.Subscriptions

  # W174: the client submits StoreKit 2's signed transaction and the SERVER
  # decides entitlement. Ad exemption and Plus gating are both computed
  # server-side, so is_subscriber is only ever set from a JWS whose x5c chain
  # verified to the pinned Apple root — never from anything the client asserts.

  def verify(conn, %{"jws" => jws}) when is_binary(jws) do
    user = conn.assigns.current_user

    with {:ok, transaction} <- AppStore.verify_transaction(jws),
         {:ok, updated} <- Subscriptions.apply_transaction(user, transaction) do
      json(conn, %{
        data: %{
          is_subscriber: updated.is_subscriber,
          product_id: transaction.product_id,
          environment: transaction.environment,
          expires_at: transaction.expires_at,
          original_transaction_id: transaction.original_transaction_id
        }
      })
    end
  end

  # The is_binary/1 guard above is deliberate: a client that double-encodes the
  # transaction (a map, a number, a base64 wrapper) fails here with a clean 422
  # rather than a 500 deep inside JOSE. Build 15 shipped a double-encoded
  # bearer on the Apple Sign In path and locked every Apple user out; this is
  # the same JOSE surface, so the malformed case is an explicit branch.
  def verify(_conn, _params), do: {:error, :invalid_jws}
end
