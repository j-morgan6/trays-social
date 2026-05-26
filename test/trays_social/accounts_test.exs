defmodule TraysSocial.AccountsTest do
  use TraysSocial.DataCase

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocial.Accounts.UserToken

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end

    test "returns an Apple Sign In user once a password has been set" do
      # Regression: D36 — Apple-Sign-In users (apple_id set, hashed_password nil
      # at registration) were reportedly unable to log in via email/password
      # even after a password was set. The current valid_password?/2 matches
      # the canonical phx.gen.auth pattern and has no apple_id reject, so the
      # dual-auth path works as long as the password is set via the canonical
      # changeset (Accounts.update_user_password/2). This test locks that in.
      {:ok, apple_user} =
        Accounts.find_or_create_apple_user(%{
          apple_id: "001234.abc#{System.unique_integer([:positive])}",
          email: unique_user_email(),
          username: unique_user_username(),
          age_confirmation: true
        })

      assert is_nil(apple_user.hashed_password)
      assert is_binary(apple_user.apple_id)

      {:ok, {%{id: id}, _}} =
        Accounts.update_user_password(apple_user, %{password: valid_user_password()})

      assert %User{id: ^id, apple_id: apple_id} =
               Accounts.get_user_by_email_and_password(apple_user.email, valid_user_password())

      assert is_binary(apple_id)
    end

    test "does not return an Apple Sign In user with no password set" do
      {:ok, apple_user} =
        Accounts.find_or_create_apple_user(%{
          apple_id: "001234.abc#{System.unique_integer([:positive])}",
          email: unique_user_email(),
          username: unique_user_username(),
          age_confirmation: true
        })

      assert is_nil(apple_user.hashed_password)
      refute Accounts.get_user_by_email_and_password(apple_user.email, valid_user_password())
    end

    test "does not return an Apple Sign In user when password is wrong" do
      {:ok, apple_user} =
        Accounts.find_or_create_apple_user(%{
          apple_id: "001234.abc#{System.unique_integer([:positive])}",
          email: unique_user_email(),
          username: unique_user_username(),
          age_confirmation: true
        })

      {:ok, _} = Accounts.update_user_password(apple_user, %{password: valid_user_password()})

      refute Accounts.get_user_by_email_and_password(apple_user.email, "wrong password 123")
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    @tag :skip
    test "registers users without password" do
      email = unique_user_email()

      {:ok, user} =
        [email: email]
        |> valid_user_attributes()
        |> Accounts.register_user()

      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "registering with an email NOT in :admin_emails leaves is_admin=false" do
      {:ok, user} =
        [email: unique_user_email()]
        |> valid_user_attributes()
        |> Accounts.register_user()

      refute user.is_admin
    end

    test "registering alone does NOT grant admin even for allowlisted email (gate: confirmed_at)" do
      # D37 regression: email is not an authentication factor. The admin grant
      # must wait until the user proves control of the email by confirming it.
      original = Application.get_env(:trays_social, :admin_emails)
      Application.put_env(:trays_social, :admin_emails, ["admin-test@example.com"])

      try do
        {:ok, user} =
          [email: "admin-test@example.com"]
          |> valid_user_attributes()
          |> Accounts.register_user()

        refute user.is_admin
        assert is_nil(user.confirmed_at)
      after
        Application.put_env(:trays_social, :admin_emails, original)
      end
    end

    test "confirming an allowlisted email grants is_admin=true (case-insensitive)" do
      original = Application.get_env(:trays_social, :admin_emails)
      Application.put_env(:trays_social, :admin_emails, ["admin-test@example.com"])

      try do
        {:ok, user} =
          [email: "Admin-Test@Example.com"]
          |> valid_user_attributes()
          |> Accounts.register_user()

        token =
          extract_user_token(fn url_fun ->
            Accounts.deliver_user_confirmation_instructions(user, url_fun)
          end)

        {:ok, confirmed} = Accounts.confirm_user_by_token(token)
        assert confirmed.is_admin
      after
        Application.put_env(:trays_social, :admin_emails, original)
      end
    end

    test "confirming an Apple-relay email never grants admin (defense-in-depth)" do
      # Even if the relay address is mistakenly added to the allowlist, the
      # admin grant must reject it — relay emails forward to a real address
      # the operator may not control, and Apple can rotate them per-app.
      original = Application.get_env(:trays_social, :admin_emails)
      relay = "abc123@privaterelay.appleid.com"
      Application.put_env(:trays_social, :admin_emails, [relay])

      try do
        {:ok, user} =
          [email: relay]
          |> valid_user_attributes()
          |> Accounts.register_user()

        token =
          extract_user_token(fn url_fun ->
            Accounts.deliver_user_confirmation_instructions(user, url_fun)
          end)

        {:ok, confirmed} = Accounts.confirm_user_by_token(token)
        refute confirmed.is_admin
      after
        Application.put_env(:trays_social, :admin_emails, original)
      end
    end

    test "is_admin is not castable from registration attrs" do
      {:ok, user} =
        [email: unique_user_email()]
        |> valid_user_attributes()
        |> Map.put(:is_admin, true)
        |> Accounts.register_user()

      # Email isn't in the allowlist; the is_admin: true in attrs is dropped.
      refute user.is_admin
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.utc_now(:second) |> DateTime.add(-3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    setup do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      %{user: user, token: encoded_token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_magic_link_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_magic_link_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_magic_link_token(token)
    end
  end

  describe "login_user_by_magic_link/1" do
    @tag :skip
    test "confirms user and expires tokens" do
      user = unconfirmed_user_fixture()
      refute user.confirmed_at
      {encoded_token, hashed_token} = generate_user_magic_link_token(user)

      assert {:ok, {user, [%{token: ^hashed_token}]}} =
               Accounts.login_user_by_magic_link(encoded_token)

      assert user.confirmed_at
    end

    test "returns user and (deleted) token for confirmed user" do
      user = user_fixture()
      assert user.confirmed_at
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      assert {:ok, {^user, []}} = Accounts.login_user_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed user has password set" do
      user = unconfirmed_user_fixture()
      {1, nil} = Repo.update_all(User, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_user_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{user: unconfirmed_user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "login"
    end
  end

  describe "get_user_by_username/1" do
    test "does not return the user if the username does not exist" do
      refute Accounts.get_user_by_username("nonexistent")
    end

    test "returns the user if the username exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_username(user.username)
    end
  end

  describe "update_user_profile/2" do
    setup do
      %{user: user_fixture()}
    end

    test "updates bio successfully", %{user: user} do
      assert {:ok, updated} = Accounts.update_user_profile(user, %{bio: "New bio"})
      assert updated.bio == "New bio"
    end

    test "updates username successfully", %{user: user} do
      assert {:ok, updated} = Accounts.update_user_profile(user, %{username: "newname"})
      assert updated.username == "newname"
    end

    test "updates profile_photo_url successfully", %{user: user} do
      url = "https://example.com/photo.jpg"
      assert {:ok, updated} = Accounts.update_user_profile(user, %{profile_photo_url: url})
      assert updated.profile_photo_url == url
    end

    test "rejects blank username", %{user: user} do
      assert {:error, changeset} = Accounts.update_user_profile(user, %{username: ""})
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects username shorter than 3 characters", %{user: user} do
      assert {:error, changeset} = Accounts.update_user_profile(user, %{username: "ab"})
      assert "should be at least 3 character(s)" in errors_on(changeset).username
    end

    test "rejects username longer than 30 characters", %{user: user} do
      long_name = String.duplicate("a", 31)
      assert {:error, changeset} = Accounts.update_user_profile(user, %{username: long_name})
      assert "should be at most 30 character(s)" in errors_on(changeset).username
    end

    test "rejects bio longer than 500 characters", %{user: user} do
      long_bio = String.duplicate("a", 501)
      assert {:error, changeset} = Accounts.update_user_profile(user, %{bio: long_bio})
      assert "should be at most 500 character(s)" in errors_on(changeset).bio
    end
  end

  describe "change_user_profile/2" do
    test "returns a changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user_profile(user)
    end

    test "returns a changeset with attrs applied" do
      user = user_fixture()
      changeset = Accounts.change_user_profile(user, %{bio: "Hello"})
      assert Ecto.Changeset.get_change(changeset, :bio) == "Hello"
    end
  end

  describe "delete_account/1" do
    test "deletes user, soft-deletes posts, and removes tokens" do
      user = user_fixture()
      _token = Accounts.generate_user_session_token(user)

      # Create a post for this user
      {:ok, post} =
        TraysSocial.Posts.create_post(user.id, %{
          caption: "Test post",
          photo_url: "https://example.com/photo.jpg",
          cooking_time_minutes: 30,
          ingredients: [%{name: "Test ingredient", quantity: "1", unit: "cup"}],
          cooking_steps: [%{description: "Test step", order: 0}]
        })

      assert {:ok, _} = Accounts.delete_account(user)

      # Post should be deleted
      refute TraysSocial.Repo.get(TraysSocial.Posts.Post, post.id)

      # All tokens should be deleted
      refute TraysSocial.Repo.get_by(UserToken, user_id: user.id)

      # User record should be deleted
      refute TraysSocial.Repo.get(User, user.id)
    end

    test "works when user has no posts or tokens" do
      user = user_fixture()
      assert {:ok, _} = Accounts.delete_account(user)
      refute TraysSocial.Repo.get(User, user.id)
    end
  end

  describe "follow_user/2" do
    setup do
      %{user1: user_fixture(), user2: user_fixture()}
    end

    test "follows a user successfully", %{user1: user1, user2: user2} do
      assert {:ok, follow} = Accounts.follow_user(user1, user2)
      assert follow.follower_id == user1.id
      assert follow.followed_id == user2.id
    end

    test "is idempotent (no-op if already following)", %{user1: user1, user2: user2} do
      assert {:ok, _follow} = Accounts.follow_user(user1, user2)
      assert {:ok, _follow} = Accounts.follow_user(user1, user2)
      # Should still only have one follow record
      assert Accounts.get_follower_count(user2.id) == 1
    end

    test "cannot follow yourself", %{user1: user1} do
      assert {:error, :cannot_follow_self} = Accounts.follow_user(user1, user1)
    end

    test "creates a notification for the followed user", %{user1: user1, user2: user2} do
      assert {:ok, _follow} = Accounts.follow_user(user1, user2)

      notification =
        TraysSocial.Repo.get_by(TraysSocial.Notifications.Notification,
          user_id: user2.id,
          actor_id: user1.id,
          type: "follow"
        )

      assert notification != nil
    end
  end

  describe "unfollow_user/2" do
    setup do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _follow} = Accounts.follow_user(user1, user2)
      %{user1: user1, user2: user2}
    end

    test "unfollows a user successfully", %{user1: user1, user2: user2} do
      assert :ok = Accounts.unfollow_user(user1, user2)
      refute Accounts.following?(user1.id, user2.id)
    end

    test "is idempotent (no-op if not following)", %{user1: user1, user2: user2} do
      assert :ok = Accounts.unfollow_user(user1, user2)
      assert :ok = Accounts.unfollow_user(user1, user2)
    end
  end

  describe "following?/2" do
    setup do
      %{user1: user_fixture(), user2: user_fixture()}
    end

    test "returns true when following", %{user1: user1, user2: user2} do
      {:ok, _follow} = Accounts.follow_user(user1, user2)
      assert Accounts.following?(user1.id, user2.id)
    end

    test "returns false when not following", %{user1: user1, user2: user2} do
      refute Accounts.following?(user1.id, user2.id)
    end

    test "is directional (A follows B does not mean B follows A)", %{user1: user1, user2: user2} do
      {:ok, _follow} = Accounts.follow_user(user1, user2)
      assert Accounts.following?(user1.id, user2.id)
      refute Accounts.following?(user2.id, user1.id)
    end
  end

  describe "has_follows?/1" do
    test "returns false when user follows nobody" do
      user = user_fixture()
      refute Accounts.has_follows?(user.id)
    end

    test "returns true when user follows someone" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _follow} = Accounts.follow_user(user1, user2)
      assert Accounts.has_follows?(user1.id)
    end

    test "returns false for the followed user if they don't follow back" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _follow} = Accounts.follow_user(user1, user2)
      refute Accounts.has_follows?(user2.id)
    end
  end

  describe "get_follower_count/1" do
    test "returns 0 when user has no followers" do
      user = user_fixture()
      assert Accounts.get_follower_count(user.id) == 0
    end

    test "returns correct count with multiple followers" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, _} = Accounts.follow_user(user1, user3)
      {:ok, _} = Accounts.follow_user(user2, user3)

      assert Accounts.get_follower_count(user3.id) == 2
    end

    test "decreases when someone unfollows" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} = Accounts.follow_user(user1, user2)
      assert Accounts.get_follower_count(user2.id) == 1

      :ok = Accounts.unfollow_user(user1, user2)
      assert Accounts.get_follower_count(user2.id) == 0
    end
  end

  describe "get_following_count/1" do
    test "returns 0 when user follows nobody" do
      user = user_fixture()
      assert Accounts.get_following_count(user.id) == 0
    end

    test "returns correct count when following multiple users" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, _} = Accounts.follow_user(user1, user2)
      {:ok, _} = Accounts.follow_user(user1, user3)

      assert Accounts.get_following_count(user1.id) == 2
    end

    test "decreases when unfollowing" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} = Accounts.follow_user(user1, user2)
      assert Accounts.get_following_count(user1.id) == 1

      :ok = Accounts.unfollow_user(user1, user2)
      assert Accounts.get_following_count(user1.id) == 0
    end
  end

  describe "Follow.changeset/2" do
    alias TraysSocial.Accounts.Follow

    test "valid changeset with follower_id and followed_id" do
      changeset = Follow.changeset(%Follow{}, %{follower_id: 1, followed_id: 2})
      assert changeset.valid?
    end

    test "requires follower_id" do
      changeset = Follow.changeset(%Follow{}, %{followed_id: 2})
      refute changeset.valid?
      assert %{follower_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires followed_id" do
      changeset = Follow.changeset(%Follow{}, %{follower_id: 1})
      refute changeset.valid?
      assert %{followed_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects self-follow" do
      changeset = Follow.changeset(%Follow{}, %{follower_id: 1, followed_id: 1})
      refute changeset.valid?
      assert %{followed_id: ["cannot follow yourself"]} = errors_on(changeset)
    end

    test "allows different follower and followed ids" do
      changeset = Follow.changeset(%Follow{}, %{follower_id: 1, followed_id: 2})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :follower_id) == 1
      assert Ecto.Changeset.get_change(changeset, :followed_id) == 2
    end
  end

  describe "generate_user_api_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "stores SHA-256 hash, not the raw token (D38)", %{user: user} do
      token = Accounts.generate_user_api_token(user)
      raw = Base.url_decode64!(token, padding: false)
      hashed = :crypto.hash(:sha256, raw)

      # No DB row stores the raw bytes — only the hash.
      refute Repo.get_by(UserToken, token: raw)
      assert user_token = Repo.get_by(UserToken, token: hashed)
      assert user_token.context == "api"
    end

    test "a DB-stored token cannot be replayed directly (D38)", %{user: user} do
      # Threat model: an attacker reads the users_tokens table (backup leak,
      # replica, SQL injection elsewhere). The stored bytes are the SHA-256
      # hash. Passing those raw stored bytes — base64-encoded as a bearer —
      # must not authenticate, because verify hashes the bearer before
      # lookup.
      _ = Accounts.generate_user_api_token(user)
      stored = Repo.one(from t in UserToken, where: t.context == "api", select: t.token)
      replay = Base.url_encode64(stored, padding: false)

      refute Accounts.get_user_by_api_token(replay)
    end
  end

  describe "get_user_by_api_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert api_user = Accounts.get_user_by_api_token(token)
      assert api_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_api_token("oops")
    end

    test "rejects tokens older than the validity window (D38)", %{user: user, token: token} do
      # Backdate the row past the 60-day validity window. The token bytes are
      # still valid by hash, but the time filter excludes it.
      sixty_one_days_ago = DateTime.utc_now() |> DateTime.add(-61, :day) |> DateTime.truncate(:second)

      Repo.update_all(
        from(t in UserToken, where: t.user_id == ^user.id and t.context == "api"),
        set: [inserted_at: sixty_one_days_ago]
      )

      refute Accounts.get_user_by_api_token(token)
    end
  end

  describe "delete_user_api_token/1" do
    test "deletes the token", %{} do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)
      assert Accounts.get_user_by_api_token(token)
      assert Accounts.delete_user_api_token(token) == :ok
      refute Accounts.get_user_by_api_token(token)
    end

    test "is a no-op (no crash) for malformed tokens" do
      assert Accounts.delete_user_api_token("not-base64-!!!") == :ok
    end
  end

  describe "refresh tokens (W105)" do
    test "generate_user_refresh_token stores SHA-256 hash, not the raw token" do
      user = user_fixture()
      token = Accounts.generate_user_refresh_token(user)
      raw = Base.url_decode64!(token, padding: false)
      hashed = :crypto.hash(:sha256, raw)

      refute Repo.get_by(UserToken, token: raw)
      assert ut = Repo.get_by(UserToken, token: hashed)
      assert ut.context == "refresh"
    end

    test "exchange_refresh_token returns {user, fresh API bearer}" do
      user = user_fixture()
      refresh = Accounts.generate_user_refresh_token(user)

      assert {:ok, {returned_user, api_bearer}} = Accounts.exchange_refresh_token(refresh)
      assert returned_user.id == user.id

      # API bearer authenticates as the same user.
      assert auth_user = Accounts.get_user_by_api_token(api_bearer)
      assert auth_user.id == user.id
    end

    test "exchange_refresh_token rejects malformed input" do
      assert {:error, :invalid_refresh_token} =
               Accounts.exchange_refresh_token("not-base64-!!!")

      assert {:error, :invalid_refresh_token} =
               Accounts.exchange_refresh_token(nil)
    end

    test "exchange_refresh_token rejects an unknown token (well-formed bytes)" do
      bogus = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      assert {:error, :invalid_refresh_token} = Accounts.exchange_refresh_token(bogus)
    end

    test "exchange_refresh_token rejects expired tokens" do
      user = user_fixture()
      refresh = Accounts.generate_user_refresh_token(user)

      # Backdate past the 60-day window.
      sixty_one_days_ago =
        DateTime.utc_now() |> DateTime.add(-61, :day) |> DateTime.truncate(:second)

      Repo.update_all(
        from(t in UserToken, where: t.user_id == ^user.id and t.context == "refresh"),
        set: [inserted_at: sixty_one_days_ago]
      )

      assert {:error, :invalid_refresh_token} = Accounts.exchange_refresh_token(refresh)
    end

    test "password update revokes refresh tokens" do
      user = user_fixture() |> set_password()
      refresh = Accounts.generate_user_refresh_token(user)
      assert {:ok, _} = Accounts.exchange_refresh_token(refresh)

      {:ok, _} = Accounts.update_user_password(user, %{password: "new_password_xyz"})

      # All tokens (including refresh) were deleted by
      # update_user_and_delete_all_tokens.
      assert {:error, :invalid_refresh_token} = Accounts.exchange_refresh_token(refresh)
    end

    test "delete_user_refresh_token revokes only the supplied token" do
      user = user_fixture()
      a = Accounts.generate_user_refresh_token(user)
      b = Accounts.generate_user_refresh_token(user)

      assert Accounts.delete_user_refresh_token(a) == :ok
      assert {:error, :invalid_refresh_token} = Accounts.exchange_refresh_token(a)
      assert {:ok, _} = Accounts.exchange_refresh_token(b)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "User.is_suspended?/1" do
    test "returns false when suspended_until is nil" do
      refute User.is_suspended?(%User{suspended_until: nil})
    end

    test "returns false when suspended_until is in the past" do
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
      refute User.is_suspended?(%User{suspended_until: past})
    end

    test "returns true when suspended_until is in the future" do
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      assert User.is_suspended?(%User{suspended_until: future})
    end

    test "returns true for the indefinite-suspension sentinel" do
      assert User.is_suspended?(%User{suspended_until: ~U[9999-12-31 23:59:59Z]})
    end
  end

  describe "suspend_user/2 and unsuspend_user/1" do
    test "suspending with a datetime sets suspended_until" do
      user = user_fixture()
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, suspended} = Accounts.suspend_user(user, future)

      assert suspended.suspended_until == future
      assert User.is_suspended?(suspended)
    end

    test "suspending with nil uses the indefinite sentinel" do
      user = user_fixture()

      {:ok, suspended} = Accounts.suspend_user(user, nil)

      assert suspended.suspended_until == ~U[9999-12-31 23:59:59Z]
      assert User.is_suspended?(suspended)
    end

    test "unsuspending clears suspended_until" do
      user = user_fixture()
      {:ok, suspended} = Accounts.suspend_user(user, nil)
      {:ok, lifted} = Accounts.unsuspend_user(suspended)

      assert lifted.suspended_until == nil
      refute User.is_suspended?(lifted)
    end

    test "suspension persists across reloads" do
      user = user_fixture()
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      {:ok, _} = Accounts.suspend_user(user, future)

      reloaded = Accounts.get_user!(user.id)

      assert reloaded.suspended_until == future
      assert User.is_suspended?(reloaded)
    end
  end
end
