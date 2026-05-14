defmodule TraysSocial.Email.Event do
  @moduledoc """
  Persisted record of a single Resend webhook event for an email send.

  Multiple events typically share the same `email_id` (the full lifecycle of
  one send: sent -> delivered -> opened, or sent -> bounced, etc.). Each
  event has its own `event_id` which we use for idempotency — Resend retries
  webhook delivery on 5xx, and the unique index on `event_id` ensures the
  retry creates no duplicate row.

  Indexed for the two admin-view queries we run today: "list recent N
  events" and "show all events for this email_id".
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          event_id: String.t(),
          email_id: String.t(),
          event_type: String.t(),
          recipient: String.t(),
          payload: map(),
          inserted_at: DateTime.t() | nil
        }

  schema "email_events" do
    field :event_id, :string
    field :email_id, :string
    field :event_type, :string
    field :recipient, :string
    field :payload, :map

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a changeset for inserting a webhook event. All five non-timestamp
  fields are required.
  """
  def changeset(event_or_attrs \\ %__MODULE__{}, attrs) do
    event_or_attrs
    |> cast(attrs, [:event_id, :email_id, :event_type, :recipient, :payload])
    |> validate_required([:event_id, :email_id, :event_type, :recipient, :payload])
    |> unique_constraint(:event_id)
  end
end
