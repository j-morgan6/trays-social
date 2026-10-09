defmodule TraysSocialWeb.API.V1.HomeController do
  @moduledoc """
  `GET /api/v1/home?today=YYYY-MM-DD` -- every recipe-first Home section in one
  response (`TraysSocial.Home.build/2`). `today` is the client's local date so
  Tonight matches the user's day; a malformed value is a 422.
  """
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Home
  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.HomeJSON

  def show(conn, params) do
    user = conn.assigns.current_user

    with {:ok, today} <- parse_today(params["today"]) do
      home = Home.build(user, today: today)
      post_ids = Enum.map(home.jump_back_in ++ home.new_from_following, & &1.id)

      render_opts = %{
        liked_post_ids: Posts.liked_post_ids_for_user(user.id, post_ids),
        bookmarked_post_ids: Posts.bookmarked_post_ids_for_user(user.id, post_ids)
      }

      json(conn, %{data: HomeJSON.render(home, render_opts)})
    end
  end

  defp parse_today(nil), do: {:ok, Date.utc_today()}

  defp parse_today(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, {:invalid_date, "today"}}
    end
  end

  defp parse_today(_), do: {:error, {:invalid_date, "today"}}
end
