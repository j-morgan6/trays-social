defmodule TraysSocial.Monetization.Subscriptions do
  @moduledoc """
  Applies signature-verified App Store transactions to user entitlement (W174).

  This is the only module in the W174 path that writes to the database, and it
  is only ever reached with a transaction that
  `TraysSocial.Monetization.AppStore` already verified. It never accepts a
  client-supplied entitlement value — `is_subscriber` is derived from the
  signed transaction's expiry and revocation state.
  """

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocial.Monetization.AppStore

  require Logger

  @doc """
  Stamps the verified transaction on the user and syncs their entitlement.

  Returns `{:error, :transaction_already_claimed}` when the subscription is
  already bound to a DIFFERENT account. Re-verifying an already-bound
  transaction on the SAME account is the idempotent path — the entitlement is
  recomputed, which is what makes a lapsed subscription re-lock on the next
  `/verify` call rather than silently staying active.
  """
  @spec apply_transaction(User.t(), AppStore.transaction()) ::
          {:ok, User.t()} | {:error, :transaction_already_claimed | Ecto.Changeset.t()}
  def apply_transaction(%User{} = user, %{original_transaction_id: oti} = transaction) do
    case Accounts.get_user_by_apple_original_transaction_id(oti) do
      %User{id: id} when id != user.id ->
        Logger.warning("app store: transaction already claimed by another account")
        {:error, :transaction_already_claimed}

      %User{} ->
        # Already stamped on this user — just resync the flag.
        Accounts.set_subscriber(user, transaction.active?)

      nil ->
        stamp_and_sync(user, transaction)
    end
  end

  @doc """
  Applies a webhook entitlement action to whichever account holds the
  transaction.

  Returns `{:error, :user_not_found}` when no account holds it — expected and
  harmless (a purchase whose `/verify` never landed, or a deleted account), so
  callers must treat it as a 200, not an error.
  """
  @spec apply_notification(AppStore.transaction(), :grant | :revoke) ::
          {:ok, User.t()} | {:error, :user_not_found | Ecto.Changeset.t()}
  def apply_notification(%{original_transaction_id: oti} = transaction, action)
      when action in [:grant, :revoke] do
    case Accounts.get_user_by_apple_original_transaction_id(oti) do
      %User{} = user -> Accounts.set_subscriber(user, grant?(transaction, action))
      nil -> {:error, :user_not_found}
    end
  end

  # Replay / out-of-order guard. Entitlement is derived from the VERIFIED
  # transaction's own expiry and revocation state, not from the notification
  # type alone — otherwise a validly-signed but stale SUBSCRIBED/DID_RENEW,
  # replayed against the unauthenticated webhook or simply delivered out of
  # order (which Apple documents as possible), would resurrect an entitlement
  # that has already lapsed.
  #
  # The revoke direction stays unconditional so it always fails closed.
  defp grant?(transaction, :grant), do: transaction.active?
  defp grant?(_transaction, :revoke), do: false

  # Two-layer collision handling. The check in apply_transaction/2 covers the
  # ordinary case; this constraint backstop covers the concurrent race, where
  # both callers see nil and both try to stamp. Without it the loser gets a
  # raw Postgrex constraint error surfaced as a 500.
  defp stamp_and_sync(user, transaction) do
    case Accounts.set_apple_original_transaction_id(user, transaction.original_transaction_id) do
      {:ok, stamped} ->
        Accounts.set_subscriber(stamped, transaction.active?)

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if Keyword.has_key?(errors, :apple_original_transaction_id) do
          Logger.warning("app store: lost the race to claim a transaction")
          {:error, :transaction_already_claimed}
        else
          {:error, changeset}
        end
    end
  end
end
