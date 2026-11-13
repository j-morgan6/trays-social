defmodule TraysSocialWeb.ExistingAccountNotice do
  @moduledoc """
  D123: when a registration attempt fails because its email already has an
  account, tell the account owner instead of telling the person registering.

  The registration response is the same whatever happens here: the form or
  the API shows the neutral `User.email_taken_message/0` on the email field.
  The notice is rate limited per address
  (`TraysSocialWeb.AuthRateLimit.check_existing_account_notice/1`) and sent
  from `TraysSocial.MailerTaskSupervisor`, so the request never waits on the
  mailer and a send failure (logged and reported by `UserNotifier.deliver/4`)
  never reaches the caller.

  Registration only. The email-change flows show the same neutral message
  but never send the notice: the signed-in user there does not own the
  address they typed. They are rate limited per user instead
  (`AuthRateLimit.check_email_change/1`).

  Known limitation, accepted on 2026-11-13: the neutral message still
  appears only when the address has an account, and a fresh address
  creates an account, so registration can still tell whether an email is
  registered. Closing that needs email confirmation before the account
  exists, which the MVP skips. Probing is bounded by the registration
  limits (web 5 per IP per hour, API 5 per minute per IP, IPv6 by /64) and
  by the email-change limit (5 per user per hour).
  """

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocialWeb.AuthRateLimit

  @doc """
  Sends the existing-account notice when `changeset` failed registration on
  a taken email. Always returns `:ok`.
  """
  @spec maybe_send(Ecto.Changeset.t()) :: :ok
  def maybe_send(%Ecto.Changeset{} = changeset) do
    # The notice goes to the stored address (citext lookup), and the limiter
    # is keyed by it, so case variants of one email share a single bucket.
    with true <- User.email_taken?(changeset),
         email when is_binary(email) <- Ecto.Changeset.get_field(changeset, :email),
         %User{} = user <- Accounts.get_user_by_email(email),
         :ok <- AuthRateLimit.check_existing_account_notice(user.email) do
      _ =
        Task.Supervisor.start_child(TraysSocial.MailerTaskSupervisor, fn ->
          Accounts.deliver_existing_account_notice(user)
        end)
    end

    :ok
  end
end
