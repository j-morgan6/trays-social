defmodule TraysSocial.MealPlans.MealPlanEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meal_plan_entries" do
    field :date, :date

    belongs_to :user, TraysSocial.Accounts.User
    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(meal_plan_entry, attrs) do
    meal_plan_entry
    |> cast(attrs, [:user_id, :date, :post_id])
    |> validate_required([:user_id, :date, :post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:user_id, :date, :post_id])
  end
end
