defmodule TraysSocialWeb.API.AuthPlug do
  @moduledoc """
  Plug that authenticates API requests via Bearer tokens.

  Extracts the token from the Authorization header and loads the user
  from the user_tokens table with the "api" context. Suspended users are
  rejected with a structured 403 the iOS client recognizes.
  """

  import Plug.Conn

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         user when not is_nil(user) <- Accounts.get_user_by_api_token(token) do
      if User.is_suspended?(user) do
        send_suspended(conn, user)
      else
        assign(conn, :current_user, user)
      end
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: [%{message: "unauthorized"}]})
        |> halt()
    end
  end

  # Structured 403 body shape — iOS APIClient pattern-matches on
  # `errors[0].code == "suspended"` and surfaces the message + end-date.
  def send_suspended(conn, %User{} = user) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{
      errors: [
        %{
          code: "suspended",
          message: "Your account has been suspended.",
          suspended_until: serialize_suspended_until(user.suspended_until)
        }
      ]
    })
    |> halt()
  end

  # Indefinite suspensions serialize as nil so clients don't render the
  # year-9999 sentinel as a confusing date. Bounded suspensions go out as
  # ISO8601 for client-side formatting.
  defp serialize_suspended_until(%DateTime{} = dt) do
    if Accounts.indefinite_suspension?(dt), do: nil, else: DateTime.to_iso8601(dt)
  end

  defp serialize_suspended_until(_), do: nil

  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _ -> :error
    end
  end
end
