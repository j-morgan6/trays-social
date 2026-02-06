defmodule TraysSocial.Repo do
  use Ecto.Repo,
    otp_app: :trays_social,
    adapter: Ecto.Adapters.Postgres
end
