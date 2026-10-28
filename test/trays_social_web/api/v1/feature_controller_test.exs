defmodule TraysSocialWeb.API.V1.FeatureControllerTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  setup :register_and_api_authenticate_user

  setup do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    %{original: original}
  end

  test "reports recipe_first off", %{conn: conn} do
    assert %{"data" => %{"recipe_first" => false}} =
             conn |> get(~p"/api/v1/features") |> json_response(200)
  end

  test "reports recipe_first on", %{conn: conn, original: original} do
    Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

    assert %{"data" => %{"recipe_first" => true}} =
             conn |> get(~p"/api/v1/features") |> json_response(200)
  end

  test "reports paid_tier off by default", %{conn: conn, original: original} do
    Application.put_env(:trays_social, :features, Keyword.delete(original, :paid_tier))

    assert %{"data" => %{"paid_tier" => false}} =
             conn |> get(~p"/api/v1/features") |> json_response(200)
  end

  test "reports paid_tier on when the :paid_tier flag is true", %{conn: conn, original: original} do
    Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, true))

    assert %{"data" => %{"paid_tier" => true}} =
             conn |> get(~p"/api/v1/features") |> json_response(200)
  end

  test "paid_tier stays off for any value other than the literal true",
       %{conn: conn, original: original} do
    Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, "true"))

    assert %{"data" => %{"paid_tier" => false}} =
             conn |> get(~p"/api/v1/features") |> json_response(200)
  end

  test "returns only the client flags (keys are paid_tier and recipe_first)", %{conn: conn} do
    assert %{"data" => data} = conn |> get(~p"/api/v1/features") |> json_response(200)
    assert data |> Map.keys() |> Enum.sort() == ["paid_tier", "recipe_first"]
  end

  test "401 without a token" do
    conn =
      build_conn()
      |> put_req_header("accept", "application/json")
      |> get(~p"/api/v1/features")

    assert json_response(conn, 401)
  end
end
