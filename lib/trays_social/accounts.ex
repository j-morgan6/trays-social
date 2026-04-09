defmodule TraysSocial.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias TraysSocial.Repo

  alias TraysSocial.Accounts.Follow
  alias TraysSocial.Accounts.User
  alias TraysSocial.Accounts.UserNotifier
  alias TraysSocial.Accounts.UserToken

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by username.

  ## Examples

      iex> get_user_by_username("johndoe")
      %User{}

      iex> get_user_by_username("unknown")
      nil

  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Finds an existing user by apple_id or creates a new one.

  Returns `{:ok, user}` on success or `{:error, changeset}` on failure.
  """
  def find_or_create_apple_user(%{apple_id: apple_id} = attrs) do
    case Repo.get_by(User, apple_id: apple_id) do
      nil ->
        %User{}
        |> User.apple_registration_changeset(Map.new(attrs, fn {k, v} -> {to_string(k), v} end))
        |> Repo.insert()

      user ->
        {:ok, user}
    end
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `TraysSocial.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `TraysSocial.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  @doc """
  Updates the user profile (username, bio, profile_photo_url).

  ## Examples

      iex> update_user_profile(user, %{bio: "New bio"})
      {:ok, %User{}}

      iex> update_user_profile(user, %{username: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user profile changes.
  """
  def change_user_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Soft deletes a user account and all their posts.

  ## Examples

      iex> delete_account(user)
      {:ok, %User{}}

  """
  def delete_account(user) do
    import Ecto.Query

    Repo.transaction(fn ->
      user_id = user.id

      # Delete comments by this user
      from(c in TraysSocial.Posts.Comment, where: c.user_id == ^user_id)
      |> Repo.delete_all()

      # Delete likes by this user
      from(l in TraysSocial.Posts.PostLike, where: l.user_id == ^user_id)
      |> Repo.delete_all()

      # Delete notifications (both as recipient and actor)
      from(n in TraysSocial.Notifications.Notification, where: n.user_id == ^user_id or n.actor_id == ^user_id)
      |> Repo.delete_all()

      # Delete follows
      from(f in Follow, where: f.follower_id == ^user_id or f.followed_id == ^user_id)
      |> Repo.delete_all()

      # Delete post associations then posts (user deletion requires full cleanup)
      post_ids =
        from(p in TraysSocial.Posts.Post, where: p.user_id == ^user_id, select: p.id)
        |> Repo.all()

      if post_ids != [] do
        from(i in TraysSocial.Posts.Ingredient, where: i.post_id in ^post_ids) |> Repo.delete_all()
        from(s in TraysSocial.Posts.CookingStep, where: s.post_id in ^post_ids) |> Repo.delete_all()
        from(t in TraysSocial.Posts.Tool, where: t.post_id in ^post_ids) |> Repo.delete_all()
        from(t in TraysSocial.Posts.PostTag, where: t.post_id in ^post_ids) |> Repo.delete_all()
        from(ph in TraysSocial.Posts.PostPhoto, where: ph.post_id in ^post_ids) |> Repo.delete_all()
        from(l in TraysSocial.Posts.PostLike, where: l.post_id in ^post_ids) |> Repo.delete_all()
        from(c in TraysSocial.Posts.Comment, where: c.post_id in ^post_ids) |> Repo.delete_all()
      end

      from(p in TraysSocial.Posts.Post, where: p.user_id == ^user_id)
      |> Repo.delete_all()

      # Delete all user tokens to log them out everywhere
      from(t in UserToken, where: t.user_id == ^user_id)
      |> Repo.delete_all()

      # Delete the user record itself (Apple App Store requirement)
      Repo.delete!(user)
    end)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    from(UserToken, where: [token: ^token, context: "session"]) |> Repo.delete_all()
    :ok
  end

  @doc """
  Generates an API token for mobile app authentication.
  """
  def generate_user_api_token(user) do
    {token, user_token} = UserToken.build_api_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given API token.
  """
  def get_user_by_api_token(token) do
    {:ok, query} = UserToken.verify_api_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the given API token.
  """
  def delete_user_api_token(token) do
    from(UserToken, where: [token: ^token, context: "api"]) |> Repo.delete_all()
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Follow system

  @doc """
  Follows a user. No-op if already following.
  """
  def follow_user(follower, followed) when follower.id != followed.id do
    result =
      %Follow{}
      |> Follow.changeset(%{follower_id: follower.id, followed_id: followed.id})
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:follower_id, :followed_id])

    case result do
      {:ok, follow} when not is_nil(follow.id) ->
        TraysSocial.Notifications.create_notification(%{
          type: "follow",
          user_id: followed.id,
          actor_id: follower.id
        })

        {:ok, follow}

      other ->
        other
    end
  end

  def follow_user(_follower, _followed), do: {:error, :cannot_follow_self}

  @doc """
  Unfollows a user.
  """
  def unfollow_user(follower, followed) do
    from(f in Follow, where: f.follower_id == ^follower.id and f.followed_id == ^followed.id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Returns true if follower is following followed.
  """
  def following?(follower_id, followed_id) do
    from(f in Follow, where: f.follower_id == ^follower_id and f.followed_id == ^followed_id)
    |> Repo.exists?()
  end

  @doc """
  Returns the number of followers for a user.
  """
  def get_follower_count(user_id) do
    from(f in Follow, where: f.followed_id == ^user_id) |> Repo.aggregate(:count)
  end

  @doc """
  Returns the number of users a user is following.
  """
  def get_following_count(user_id) do
    from(f in Follow, where: f.follower_id == ^user_id) |> Repo.aggregate(:count)
  end

  @doc """
  Returns true if the user has any follows (is following at least one person).
  """
  def has_follows?(user_id) do
    from(f in Follow, where: f.follower_id == ^user_id) |> Repo.exists?()
  end

  @doc """
  Returns a cursor-paginated list of users who follow the given user.
  """
  def list_followers(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    cursor_id = Keyword.get(opts, :cursor_id)

    query =
      Follow
      |> where([f], f.followed_id == ^user_id)
      |> join(:inner, [f], u in User, on: u.id == f.follower_id)
      |> order_by([f], desc: f.inserted_at)
      |> limit(^limit)
      |> select([f, u], u)

    query =
      if cursor_id do
        where(query, [f], f.follower_id < ^cursor_id)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Returns a cursor-paginated list of users the given user follows.
  """
  def list_following(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    cursor_id = Keyword.get(opts, :cursor_id)

    query =
      Follow
      |> where([f], f.follower_id == ^user_id)
      |> join(:inner, [f], u in User, on: u.id == f.followed_id)
      |> order_by([f], desc: f.inserted_at)
      |> limit(^limit)
      |> select([f, u], u)

    query =
      if cursor_id do
        where(query, [f], f.followed_id < ^cursor_id)
      else
        query
      end

    Repo.all(query)
  end

  def search_users(query_string, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    if query_string && query_string != "" do
      sanitized = "%#{sanitize_like(query_string)}%"

      User
      |> where([u], ilike(u.username, ^sanitized))
      |> order_by([u], asc: u.username)
      |> limit(^limit)
      |> Repo.all()
    else
      []
    end
  end

  defp sanitize_like(string) do
    string
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
