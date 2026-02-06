defmodule TraysSocial.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias TraysSocial.Repo

  alias TraysSocial.Posts.{Post, Ingredient, Tool, CookingStep, PostTag}

  @doc """
  Returns the list of posts, excluding soft deleted posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts do
    Post
    |> where([p], is_nil(p.deleted_at))
    |> order_by([p], desc: p.inserted_at)
    |> preload([:user, :ingredients, :tools, :cooking_steps, :post_tags])
    |> Repo.all()
  end

  @doc """
  Returns the list of posts for a specific user, excluding soft deleted posts.

  ## Examples

      iex> list_posts_by_user(user_id)
      [%Post{}, ...]

  """
  def list_posts_by_user(user_id) do
    Post
    |> where([p], p.user_id == ^user_id and is_nil(p.deleted_at))
    |> order_by([p], desc: p.inserted_at)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist or is deleted.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id) do
    Post
    |> where([p], is_nil(p.deleted_at))
    |> preload([:user, :ingredients, :tools, :cooking_steps, :post_tags])
    |> Repo.get!(id)
  end

  @doc """
  Creates a post with nested associations.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Ecto.Changeset.cast_assoc(:ingredients, with: &Ingredient.changeset/2)
    |> Ecto.Changeset.cast_assoc(:tools, with: &Tool.changeset/2)
    |> Ecto.Changeset.cast_assoc(:cooking_steps, with: &CookingStep.changeset/2)
    |> Ecto.Changeset.cast_assoc(:post_tags, with: &PostTag.changeset/2)
    |> Repo.insert()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Soft deletes a post by setting deleted_at timestamp.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    post
    |> Ecto.Changeset.change(%{deleted_at: DateTime.utc_now(:second)})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end
end
