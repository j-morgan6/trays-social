defmodule TraysSocialWeb.UserSessionHTML do
  use TraysSocialWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:trays_social, TraysSocial.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
