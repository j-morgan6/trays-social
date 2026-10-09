defmodule TraysSocialWeb.API.V1.HomeControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.MealPlans

  setup :register_and_api_authenticate_user

  test "returns every section", %{conn: conn, user: user} do
    friend = user_fixture()
    {:ok, _} = Accounts.follow_user(user, friend)
    mine = post_fixture(%{user_id: user.id})
    fresh = post_fixture(%{user_id: friend.id})
    {:ok, _} = MealPlans.create_entry(user, ~D[2026-10-08], mine)

    data =
      conn
      |> get(~p"/api/v1/home?today=2026-10-08")
      |> json_response(200)
      |> Map.fetch!("data")

    assert data |> Map.keys() |> Enum.sort() ==
             ~w(friends_trays jump_back_in new_from_following suggested_cooks tonight)

    assert [%{"id" => id}] = data["jump_back_in"]
    assert id == mine.id
    assert data["tonight"]["post"]["id"] == mine.id
    assert [%{"username" => username, "last_posted_at" => at}] = data["friends_trays"]
    assert username == friend.username
    assert {:ok, _, 0} = DateTime.from_iso8601(at)
    assert String.ends_with?(at, "Z")
    assert [%{"id" => fresh_id}] = data["new_from_following"]
    assert fresh_id == fresh.id
    assert data["suggested_cooks"] == []
  end

  test "suggests cooks to a viewer who follows no one", %{conn: conn} do
    cook = user_fixture()
    post_fixture(%{user_id: cook.id})

    data = conn |> get(~p"/api/v1/home") |> json_response(200) |> Map.fetch!("data")

    assert [%{"id" => id, "username" => username, "recipe_count" => 1}] =
             data["suggested_cooks"]

    assert id == cook.id
    assert username == cook.username
  end

  test "honours a client today ahead of UTC", %{conn: conn, user: user} do
    mine = post_fixture(%{user_id: user.id})
    tomorrow = Date.add(Date.utc_today(), 1)
    {:ok, _} = MealPlans.create_entry(user, tomorrow, mine)

    data =
      conn
      |> get(~p"/api/v1/home?today=#{Date.to_iso8601(tomorrow)}")
      |> json_response(200)
      |> Map.fetch!("data")

    assert data["tonight"]["post"]["id"] == mine.id
  end

  test "tonight is null without a plan", %{conn: conn} do
    assert %{"data" => %{"tonight" => nil, "jump_back_in" => []}} =
             conn |> get(~p"/api/v1/home") |> json_response(200)
  end

  test "422 for a malformed date", %{conn: conn} do
    assert %{"errors" => [%{"field" => "today"}]} =
             conn |> get(~p"/api/v1/home?today=yesterday") |> json_response(422)
  end

  test "401 without a token" do
    conn =
      build_conn()
      |> put_req_header("accept", "application/json")
      |> get(~p"/api/v1/home")

    assert json_response(conn, 401)
  end
end
