defmodule TraysSocial.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_target_types ~w(post comment user)
  @valid_reasons ~w(spam off_topic harassment inappropriate other)
  schema "reports" do
    field :target_type, :string
    field :target_id, :integer
    field :reason, :string
    field :details, :string
    field :status, :string, default: "open"
    field :resolved_at, :utc_datetime

    belongs_to :reporter, TraysSocial.Accounts.User
    belongs_to :resolved_by, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:reporter_id, :target_type, :target_id, :reason, :details])
    |> validate_required([:reporter_id, :target_type, :target_id, :reason])
    |> validate_inclusion(:target_type, @valid_target_types)
    |> validate_inclusion(:reason, @valid_reasons)
    |> validate_length(:details, max: 1000)
    |> foreign_key_constraint(:reporter_id)
    |> unique_constraint([:reporter_id, :target_type, :target_id],
      name: :reports_reporter_target_unique,
      message: "you have already reported this content"
    )
  end

  def resolve_changeset(report, attrs) do
    report
    |> cast(attrs, [:status, :resolved_at, :resolved_by_id])
    |> validate_required([:status, :resolved_at, :resolved_by_id])
    |> validate_inclusion(:status, ["resolved", "dismissed"])
  end
end
