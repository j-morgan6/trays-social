defmodule TraysSocialWeb.API.V1.RecipeOnlyCreateTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  setup :register_and_api_authenticate_user

  setup do
    original = Application.get_env(:trays_social, :features, [])
    Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    :ok
  end

  describe "POST /api/v1/posts with recipe_first on" do
    test "an old app creating a photo post gets the update message", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/posts", %{
          type: "post",
          photo_url: "/uploads/a.jpg",
          caption: "Dinner out"
        })

      assert %{"errors" => errors} = json_response(conn, 422)

      assert %{"field" => "type", "message" => "Posts need a recipe now. Update Trays to post."} in errors
    end
  end
end
