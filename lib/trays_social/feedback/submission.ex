defmodule TraysSocial.Feedback.Submission do
  @moduledoc """
  One user-typed feedback submission from inside the iOS app.

  Captured during external TestFlight beta so testers have a one-tap
  channel that's lower-friction than email. Admins triage via the
  `/admin/feedback` LiveView (W124).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(new triaged resolved)

  schema "feedback_submissions" do
    field :subject, :string
    field :body, :string
    field :app_version, :string
    field :os_version, :string
    field :device_model, :string
    field :status, :string, default: "new"

    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def submit_changeset(submission, attrs) do
    submission
    |> cast(attrs, [:user_id, :subject, :body, :app_version, :os_version, :device_model])
    |> update_change(:body, &maybe_trim/1)
    |> validate_required([:user_id, :body])
    |> validate_length(:subject, max: 200)
    |> validate_length(:body, min: 1, max: 5000)
    |> validate_length(:app_version, max: 64)
    |> validate_length(:os_version, max: 64)
    |> validate_length(:device_model, max: 128)
    |> foreign_key_constraint(:user_id)
  end

  def status_changeset(submission, status) when status in @statuses do
    change(submission, status: status)
  end

  def statuses, do: @statuses

  # Whitespace-only bodies must be treated as empty; trim before
  # validate_length so they fall through to the min: 1 check.
  defp maybe_trim(nil), do: nil
  defp maybe_trim(text) when is_binary(text), do: String.trim(text)
end
