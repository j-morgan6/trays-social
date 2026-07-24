defmodule TraysSocialWeb.API.V1.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  Used as the fallback controller for all API v1 controllers via
  `action_fallback/1`.
  """

  use TraysSocialWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: format_changeset_errors(changeset)})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: [%{message: "not found"}]})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: [%{message: "unauthorized"}]})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{errors: [%{message: "forbidden"}]})
  end

  # W172: gated Trays Plus writes for non-subscribers (or with :paid_tier
  # off). Coded-error style follows AuthPlug.send_suspended — the iOS
  # APIClient pattern-matches errors[0].code and presents the paywall on
  # "subscription_required".
  def call(conn, {:error, :subscription_required}) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      errors: [%{code: "subscription_required", message: "Trays Plus subscription required"}]
    })
  end

  # W166: writes refused between blocked user pairs.
  def call(conn, {:error, :blocked}) do
    conn
    |> put_status(:forbidden)
    |> json(%{errors: [%{message: "blocked"}]})
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn message ->
        %{field: to_string(field), message: message}
      end)
    end)
  end
end
