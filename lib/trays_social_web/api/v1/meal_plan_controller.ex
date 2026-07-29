defmodule TraysSocialWeb.API.V1.MealPlanController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.MealPlans
  alias TraysSocial.Monetization
  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.MealPlanJSON

  # W173 Trays Plus gating: planning a meal (creating an entry) requires an
  # active subscription while the paid tier is enabled. Reads, entry
  # deletes, and grocery checks are NEVER gated — a lapsed subscriber keeps
  # full access to their planned weeks (graceful re-lock).

  def show(conn, params) do
    user = conn.assigns.current_user

    with {:ok, week_start} <- parse_week_start(params["week_start"]) do
      entries = MealPlans.list_entries(user.id, week_start)

      json(conn, %{
        data: %{
          week_start: Date.to_iso8601(week_start),
          entries: MealPlanJSON.render_entries(entries)
        }
      })
    end
  end

  def create_entry(conn, params) do
    user = conn.assigns.current_user

    with :ok <- require_subscription(user),
         {:ok, date} <- parse_date(params["date"], "date") do
      try do
        post = Posts.get_post!(params["post_id"])

        case MealPlans.create_entry(user, date, post) do
          {:ok, entry} ->
            conn
            |> put_status(:created)
            |> json(%{data: MealPlanJSON.render_entry(%{entry | post: post})})

          {:error, _} = error ->
            error
        end
      rescue
        Ecto.NoResultsError -> {:error, :not_found}
        Ecto.Query.CastError -> {:error, :not_found}
      end
    end
  end

  def delete_entry(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    try do
      {:ok, _} = MealPlans.delete_entry(user.id, id)
      json(conn, %{data: %{message: "entry deleted"}})
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def grocery_list(conn, params) do
    user = conn.assigns.current_user

    with {:ok, week_start} <- parse_week_start(params["week_start"]) do
      json(conn, %{
        data: %{
          week_start: Date.to_iso8601(week_start),
          recipes:
            user.id
            |> MealPlans.grocery_list(week_start)
            |> MealPlanJSON.render_grocery_list()
        }
      })
    end
  end

  def update_check(conn, params) do
    user = conn.assigns.current_user

    with {:ok, week_start} <- parse_week_start(params["week_start"]),
         {:ok, checked} <- parse_boolean(params["checked"], "checked"),
         :ok <- MealPlans.set_check(user.id, week_start, params["item_key"], checked) do
      json(conn, %{data: %{message: "check updated"}})
    end
  end

  defp require_subscription(user) do
    if Monetization.feature_enabled?(:paid_tier) and Monetization.subscriber?(user) do
      :ok
    else
      {:error, :subscription_required}
    end
  end

  # A missing week_start means "this week"; an unparseable one becomes
  # {:error, {:invalid_date, "week_start"}} and is rendered as a 422 by
  # FallbackController. Always normalized to Monday so the response echoes
  # the canonical week key.
  defp parse_week_start(nil), do: {:ok, Date.beginning_of_week(Date.utc_today())}

  defp parse_week_start(value) do
    with {:ok, date} <- parse_date(value, "week_start") do
      {:ok, Date.beginning_of_week(date)}
    end
  end

  defp parse_date(value, field) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, {:invalid_date, field}}
    end
  end

  defp parse_date(_value, field), do: {:error, {:invalid_date, field}}

  defp parse_boolean(value, _field) when is_boolean(value), do: {:ok, value}
  defp parse_boolean(_value, field), do: {:error, {:invalid_boolean, field}}
end
