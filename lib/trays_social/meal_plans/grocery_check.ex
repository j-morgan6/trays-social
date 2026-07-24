defmodule TraysSocial.MealPlans.GroceryCheck do
  use Ecto.Schema
  import Ecto.Changeset

  # Grocery items are derived rows, not stored ones — a check references its
  # item by the stable derived key "post_id:ingredient_id" (two integer ids).
  @item_key_format ~r/\A\d+:\d+\z/

  schema "grocery_checks" do
    field :week_start, :date
    field :item_key, :string

    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(grocery_check, attrs) do
    grocery_check
    |> cast(attrs, [:user_id, :week_start, :item_key])
    |> validate_required([:user_id, :week_start, :item_key])
    |> validate_format(:item_key, @item_key_format,
      message: "must have the form \"post_id:ingredient_id\""
    )
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :week_start, :item_key])
  end
end
