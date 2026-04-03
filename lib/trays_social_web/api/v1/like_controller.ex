defmodule TraysSocialWeb.API.V1.LikeController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Posts

  def create(conn, %{"post_id" => post_id}) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(post_id)

      case Posts.like_post(post, user) do
        {:ok, _} -> json(conn, %{data: %{message: "liked", like_count: post.like_count + 1}})
        {:error, _} -> json(conn, %{data: %{message: "already liked", like_count: post.like_count}})
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end

  def delete(conn, %{"post_id" => post_id}) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(post_id)

      case Posts.unlike_post(post, user) do
        {:ok, _} -> json(conn, %{data: %{message: "unliked", like_count: max(post.like_count - 1, 0)}})
        {:error, _} -> json(conn, %{data: %{message: "not liked", like_count: post.like_count}})
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end
end
