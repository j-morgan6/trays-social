defmodule TraysSocialWeb.API.AuthPlug do
  @moduledoc """
  Plug that authenticates API requests via Bearer tokens.

  Extracts the token from the Authorization header and loads the user
  from the user_tokens table with the "api" context.
  """

  import Plug.Conn

  alias TraysSocial.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         user when not is_nil(user) <- Accounts.get_user_by_api_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: [%{message: "unauthorized"}]})
        |> halt()
    end
  end

  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, Base.decode64!(token)}
      _ -> :error
    end
  rescue
    ArgumentError -> :error
  end
end
