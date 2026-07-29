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

  # W174: every StoreKit verification failure collapses to ONE client-visible
  # code. Telling a caller which stage failed (bad signature vs untrusted
  # chain vs wrong bundle) is a free oracle for anyone probing the endpoint;
  # the specific reason is logged in AppStore.JWS and never returned.
  @invalid_transaction_reasons [
    :invalid_jws,
    :malformed_jws,
    :invalid_certificate_chain,
    :untrusted_certificate_chain,
    :invalid_signature,
    :malformed_transaction,
    :malformed_notification,
    :bundle_id_mismatch
  ]

  def call(conn, {:error, reason}) when reason in @invalid_transaction_reasons do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      errors: [%{code: "invalid_transaction", message: "transaction could not be verified"}]
    })
  end

  def call(conn, {:error, :unknown_product}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{code: "unknown_product", message: "unknown product"}]})
  end

  def call(conn, {:error, :environment_mismatch}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{code: "environment_mismatch", message: "unexpected store environment"}]})
  end

  # 409, not 422: a transaction bound to another account is a different
  # condition from an invalid one and the client must not retry it.
  def call(conn, {:error, :transaction_already_claimed}) do
    conn
    |> put_status(:conflict)
    |> json(%{
      errors: [
        %{
          code: "transaction_already_claimed",
          message: "this subscription is already linked to another account"
        }
      ]
    })
  end

  # W173: query/body params that must parse before the action can run. Same
  # body shape as the changeset clause above so clients see one validation
  # contract regardless of whether the value failed parsing or validation.
  def call(conn, {:error, {:invalid_date, field}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{field: field, message: "must be an ISO 8601 date (YYYY-MM-DD)"}]})
  end

  def call(conn, {:error, {:invalid_boolean, field}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{field: field, message: "must be a boolean"}]})
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
