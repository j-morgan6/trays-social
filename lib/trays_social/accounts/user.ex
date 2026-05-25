defmodule TraysSocial.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @age_confirmation_message "You must confirm you are 13 or older to use Trays"

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :age_confirmation, :boolean, virtual: true
    field :username, :string
    field :bio, :string
    field :profile_photo_url, :string
    field :apple_id, :string
    field :muted_keywords, {:array, :string}, default: []
    field :is_admin, :boolean, default: false
    field :seen_welcome_at, :utc_datetime
    field :suspended_until, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns true when the user is currently suspended.

  `suspended_until` is nil for active accounts. A datetime in the future means
  the user is suspended until that moment; a datetime in the past means the
  suspension has expired. Pass `~U[9999-12-31 23:59:59Z]` (the sentinel used
  by `TraysSocial.Accounts.suspend_user/2` when no end date is supplied) for
  an indefinite suspension.
  """
  def is_suspended?(%__MODULE__{suspended_until: nil}), do: false

  def is_suspended?(%__MODULE__{suspended_until: %DateTime{} = suspended_until}) do
    DateTime.after?(suspended_until, DateTime.utc_now())
  end

  # Defensive only — `nil` reaches here from `with` chains in UserAuth when
  # the session lookup fails. Anything else is a programming error and is
  # intentionally allowed to raise FunctionClauseError.
  def is_suspended?(nil), do: false

  @doc """
  Server-side-only changeset for granting/revoking admin status.

  Never callable from user-supplied params — `is_admin` is intentionally
  not in any user-facing changeset, so a malicious POST that includes
  `is_admin: true` is silently dropped.

  Use this from `TraysSocial.Accounts.set_admin/2`.
  """
  def admin_changeset(user, is_admin) when is_boolean(is_admin) do
    change(user, is_admin: is_admin)
  end

  @doc """
  A user changeset for registration.

  Validates email, username, and password fields.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :password, :age_confirmation])
    |> validate_email(opts)
    |> validate_username(opts)
    |> validate_password(opts)
    # validate_required catches the "checkbox unchecked" web case (HTML omits
    # the param entirely); validate_acceptance catches the API case where the
    # client explicitly sends false. Both use the same user-facing message.
    |> validate_required([:age_confirmation], message: @age_confirmation_message)
    |> validate_acceptance(:age_confirmation, message: @age_confirmation_message)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  @doc """
  A user changeset for Apple Sign In registration.

  Validates email and stores apple_id, but does not require a password.
  Username is optional at registration (set later via profile update).
  """
  def apple_registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :apple_id])
    |> validate_required([:email, :apple_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
    |> unique_constraint(:apple_id)
    |> maybe_validate_username(opts)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  defp maybe_validate_username(changeset, opts) do
    if get_change(changeset, :username) do
      validate_username(changeset, opts)
    else
      changeset
    end
  end

  @doc """
  A user changeset for updating profile information.

  Validates username, bio, and profile_photo_url fields.
  """
  def profile_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :bio, :profile_photo_url])
    |> validate_username(opts)
    |> validate_length(:bio, max: 500)
  end

  defp validate_username(changeset, opts) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "must contain only letters, numbers, and underscores"
    )
    |> maybe_validate_unique_username(opts)
  end

  defp maybe_validate_unique_username(changeset, opts) do
    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:username, TraysSocial.Repo)
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, TraysSocial.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%TraysSocial.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
