defmodule TraysSocialWeb.API.V1.NotificationController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Notifications
  alias TraysSocialWeb.API.V1.JSON.NotificationJSON

  @page_size 20

  def index(conn, params) do
    user = conn.assigns.current_user
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    notifications =
      Notifications.list_notifications_paginated(user.id,
        limit: @page_size,
        cursor_id: cursor_id,
        cursor_time: cursor_time
      )

    next_cursor = encode_cursor(List.last(notifications))

    json(conn, %{
      data: NotificationJSON.render_list(notifications),
      cursor: next_cursor
    })
  end

  def mark_read(conn, %{"ids" => ids}) when is_list(ids) do
    user = conn.assigns.current_user

    {:ok, count} = Notifications.mark_read(user.id, ids)

    json(conn, %{data: %{marked_read: count}})
  end

  def mark_read(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: [%{message: "ids must be an array of notification IDs"}]})
  end

  defp decode_cursor(nil), do: {nil, nil}

  defp decode_cursor(cursor) do
    case Base.url_decode64(cursor, padding: false) do
      {:ok, decoded} ->
        case String.split(decoded, ":", parts: 2) do
          [id_str, time_str] ->
            {String.to_integer(id_str), DateTime.from_iso8601(time_str) |> elem(1)}

          _ ->
            {nil, nil}
        end

      :error ->
        {nil, nil}
    end
  rescue
    _ -> {nil, nil}
  end

  defp encode_cursor(nil), do: nil

  defp encode_cursor(notification) do
    Base.url_encode64("#{notification.id}:#{DateTime.to_iso8601(notification.inserted_at)}", padding: false)
  end
end
