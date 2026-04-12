defmodule TraysSocialWeb.API.RequireConfirmedPlug do
  @moduledoc """
  Plug that rejects API requests from users who have not confirmed their email.
  Must be placed after AuthPlug in the pipeline.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{confirmed_at: confirmed_at} when not is_nil(confirmed_at) ->
        conn

      _ ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{
          errors: [%{message: "You must confirm your email before performing this action."}]
        })
        |> halt()
    end
  end
end
