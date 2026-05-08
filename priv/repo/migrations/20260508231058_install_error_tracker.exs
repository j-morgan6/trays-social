defmodule TraysSocial.Repo.Migrations.InstallErrorTracker do
  use Ecto.Migration

  def up, do: ErrorTracker.Migration.up()
  def down, do: ErrorTracker.Migration.down()
end
