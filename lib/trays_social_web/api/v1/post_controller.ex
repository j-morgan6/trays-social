defmodule TraysSocialWeb.API.V1.PostController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  def trending(conn, _params) do
    user = conn.assigns.current_user
    posts = Posts.list_trending_posts(20)
    post_ids = Enum.map(posts, & &1.id)
    liked_post_ids = Posts.liked_post_ids_for_user(user.id, post_ids)
    bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, post_ids)

    json(conn, %{
      data: PostJSON.render_list(posts, %{liked_post_ids: liked_post_ids, bookmarked_post_ids: bookmarked_post_ids})
    })
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(id)
      liked_post_ids = Posts.liked_post_ids_for_user(user.id, [post.id])
      bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, [post.id])

      json(conn, %{data: PostJSON.render(post, %{liked_post_ids: liked_post_ids, bookmarked_post_ids: bookmarked_post_ids})})
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def create(conn, params) do
    user = conn.assigns.current_user
    attrs = Map.put(params, "user_id", user.id)

    case Posts.create_post(attrs) do
      {:ok, post} ->
        post = Posts.get_post!(post.id)

        conn
        |> put_status(:created)
        |> json(%{data: PostJSON.render(post)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(id)

      if post.user_id != user.id do
        {:error, :forbidden}
      else
        case Posts.delete_post(post) do
          {:ok, _} -> json(conn, %{data: %{message: "post deleted"}})
          {:error, changeset} -> {:error, changeset}
        end
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end
end
