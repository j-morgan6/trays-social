defmodule TraysSocial.Feedback.Submission do
  @moduledoc """
  One user-typed bug report or feedback submission from the iOS app or
  the web.

  Admins triage via the `/admin/feedback` LiveView (W124).

  ## Fields

    * `kind` - `"bug"` or `"feedback"`; defaults to `"feedback"`
    * `platform` - `"ios"` or `"web"`; defaults to `"ios"` because shipped
      iOS builds send no platform (W260)
    * `subject` (max 200), `body` (required, 1 to 5,000 characters after
      trimming)
    * `app_version` (64), `app_build` (64), `os_version` (64),
      `device_model` (128), `screen` (120), `user_agent` (512); these and
      `subject` are varchar columns, so their limits count codepoints
    * `status` - `"new"`, `"triaged"` or `"resolved"`

  `user_id` is never cast from attrs (D44/D52): `TraysSocial.Feedback.submit/2`
  sets it on the struct before this changeset runs. No IP address is stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses ~w(new triaged resolved)
  @kinds ~w(bug feedback)
  @platforms ~w(ios web)

  schema "feedback_submissions" do
    field :kind, :string, default: "feedback"
    field :platform, :string, default: "ios"
    field :subject, :string
    field :body, :string
    field :app_version, :string
    field :app_build, :string
    field :os_version, :string
    field :device_model, :string
    field :screen, :string
    field :user_agent, :string
    field :status, :string, default: "new"

    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for a new submission. The caller sets `user_id` on the struct;
  a `user_id` in `attrs` is ignored.
  """
  def submit_changeset(submission, attrs) do
    submission
    |> cast(attrs, [
      :kind,
      :platform,
      :subject,
      :body,
      :app_version,
      :app_build,
      :os_version,
      :device_model,
      :screen,
      :user_agent
    ])
    # An explicit nil (or "", which cast turns into nil) overrides the
    # schema default and would hit the NOT NULL column, so fall back here.
    |> default_if_nil(:kind, "feedback")
    |> default_if_nil(:platform, "ios")
    |> update_change(:body, &maybe_trim/1)
    |> validate_required([:user_id, :kind, :platform, :body])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:platform, @platforms)
    # The varchar columns count codepoints, and validate_length counts
    # graphemes by default, so a value of N graphemes made of combining
    # marks would pass here and fail the insert (W261). The body is a
    # text column, so it keeps the grapheme count the iOS counter uses.
    |> validate_length(:subject, max: 200, count: :codepoints)
    |> validate_length(:body, min: 1, max: 5000)
    |> validate_length(:app_version, max: 64, count: :codepoints)
    |> validate_length(:app_build, max: 64, count: :codepoints)
    |> validate_length(:os_version, max: 64, count: :codepoints)
    |> validate_length(:device_model, max: 128, count: :codepoints)
    |> validate_length(:screen, max: 120, count: :codepoints)
    |> validate_length(:user_agent, max: 512, count: :codepoints)
    |> foreign_key_constraint(:user_id)
  end

  def status_changeset(submission, status) when status in @statuses do
    change(submission, status: status)
  end

  def statuses, do: @statuses
  def kinds, do: @kinds
  def platforms, do: @platforms

  defp default_if_nil(changeset, field, default) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default)
      _ -> changeset
    end
  end

  # Whitespace-only bodies must be treated as empty; trim before
  # validate_length so they fall through to the min: 1 check.
  defp maybe_trim(nil), do: nil
  defp maybe_trim(text) when is_binary(text), do: String.trim(text)
end
