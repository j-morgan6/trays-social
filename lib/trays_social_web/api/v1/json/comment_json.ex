defmodule TraysSocialWeb.API.V1.JSON.CommentJSON do
  def render(comment) do
    %{
      id: comment.id,
      body: comment.body,
      inserted_at: comment.inserted_at,
      user: render_user(comment.user)
    }
  end

  def render_list(comments) do
    Enum.map(comments, &render/1)
  end

  defp render_user(%{} = user) do
    %{
      id: user.id,
      username: user.username,
      profile_photo_url: user.profile_photo_url
    }
  end

  defp render_user(_), do: nil
end
