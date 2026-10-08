defmodule TraysSocialWeb.API.V1.IngredientSearchControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts

  setup :register_and_api_authenticate_user

  defp recipe(user, names) do
    post_fixture(%{user_id: user.id, ingredients: Enum.map(names, &%{name: &1})})
  end

  describe "GET /api/v1/search/ingredients" do
    test "groups results and reports missing ingredients", %{conn: conn, user: user} do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(user, friend)
      mine = recipe(user, ["chicken", "rice"])
      theirs = recipe(friend, ["chicken", "soy sauce"])

      conn = get(conn, ~p"/api/v1/search/ingredients?have[]=chicken&have[]=rice")

      assert %{"data" => %{"everything" => [e], "almost" => [a]}} = json_response(conn, 200)
      assert e["post"]["id"] == mine.id
      assert e["scope"] == "mine"
      assert e["missing"] == []
      assert a["post"]["id"] == theirs.id
      assert a["scope"] == "following"
      assert a["missing"] == ["soy sauce"]

      # The post payload is the full PostJSON shape, so preloads are complete.
      assert e["post"]["user"]["id"] == user.id
      assert is_list(e["post"]["ingredients"])
      assert e["post"]["liked_by_current_user"] == false
    end

    test "excludes recipes from users who blocked the viewer", %{conn: conn, user: user} do
      blocker = user_fixture()
      recipe(blocker, ["chicken"])
      {:ok, _} = Accounts.block_user(blocker.id, user.id)

      conn = get(conn, ~p"/api/v1/search/ingredients?have[]=chicken")
      assert %{"data" => %{"everything" => [], "almost" => []}} = json_response(conn, 200)
    end

    test "excludes recipes from users the viewer blocked", %{conn: conn, user: user} do
      blocked = user_fixture()
      recipe(blocked, ["chicken"])
      {:ok, _} = Accounts.block_user(user.id, blocked.id)

      conn = get(conn, ~p"/api/v1/search/ingredients?have[]=chicken")
      assert %{"data" => %{"everything" => [], "almost" => []}} = json_response(conn, 200)
    end

    test "422 when no ingredients are given", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/search/ingredients")

      assert %{
               "errors" => [
                 %{"field" => "have", "message" => "must include 1 to 10 ingredients"}
               ]
             } = json_response(conn, 422)
    end

    test "422 when only blank ingredients are given", %{conn: conn} do
      conn = get(conn, "/api/v1/search/ingredients?have[]=&have[]=%20%20")

      assert %{"errors" => [%{"field" => "have"}]} = json_response(conn, 422)
    end

    test "422 when more than 10 ingredients are given", %{conn: conn} do
      query = Enum.map_join(1..11, "&", &"have[]=item#{&1}")
      conn = get(conn, "/api/v1/search/ingredients?" <> query)

      assert %{
               "errors" => [
                 %{"field" => "have", "message" => "must include 1 to 10 ingredients"}
               ]
             } = json_response(conn, 422)
    end

    test "422 when have is a plain string instead of a list", %{conn: conn, user: user} do
      recipe(user, ["chicken"])

      conn = get(conn, ~p"/api/v1/search/ingredients?have=chicken")

      assert %{"errors" => [%{"field" => "have"}]} = json_response(conn, 422)
    end

    test "422, not a 500, when a chip carries a NUL byte", %{conn: conn, user: user} do
      recipe(user, ["chicken"])

      conn = get(conn, "/api/v1/search/ingredients?have[]=chick%00en")

      assert %{"errors" => [%{"field" => "have"}]} = json_response(conn, 422)
    end

    test "duplicate chips count once", %{conn: conn, user: user} do
      mine = recipe(user, ["chicken"])
      query = Enum.map_join(1..11, "&", fn _ -> "have[]=Chicken" end)

      conn = get(conn, "/api/v1/search/ingredients?" <> query)

      assert %{"data" => %{"everything" => [e], "almost" => []}} = json_response(conn, 200)
      assert e["post"]["id"] == mine.id
    end

    test "401 without a token" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/v1/search/ingredients?have[]=chicken")

      assert json_response(conn, 401)
    end
  end
end
