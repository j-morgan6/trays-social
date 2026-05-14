defmodule TraysSocial.Repo.Migrations.InvalidateApiTokensForHashing do
  use Ecto.Migration

  # D38: API tokens previously stored raw bytes (not hashes). The format
  # changes to SHA-256-of-(URL-base64-decoded-bearer) in this deploy. There is
  # no way to rehash existing rows in place — the raw token never returns to
  # the server after issuance — so all current API sessions are invalidated.
  # Mobile clients will receive 401 on their next request and must re-login.
  def up do
    execute("DELETE FROM users_tokens WHERE context = 'api'")
  end

  def down do
    :ok
  end
end
