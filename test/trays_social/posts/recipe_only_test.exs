defmodule TraysSocial.Posts.RecipeOnlyTest do
  # async: false: toggles the global :features config.
  use TraysSocial.DataCase, async: false

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Posts

  @message "Posts need a recipe now. Update Trays to post."

  setup do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    %{user: user_fixture(), original: original}
  end

  defp flag_on(original),
    do: Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

  describe "create_post/2 with recipe_first" do
    test "photo posts are allowed while the flag is off", %{user: user} do
      assert {:ok, %{type: "post"}} =
               Posts.create_post(user.id, %{type: "post", photo_url: "/uploads/a.jpg"})
    end

    test "photo posts are rejected while the flag is on", %{user: user, original: original} do
      flag_on(original)

      assert {:error, changeset} =
               Posts.create_post(user.id, %{type: "post", photo_url: "/uploads/a.jpg"})

      assert %{type: [@message]} = errors_on(changeset)
    end

    # post_fixture/1 omits :type, so this also covers the schema default.
    test "recipes still work while the flag is on", %{user: user, original: original} do
      flag_on(original)
      assert %{type: "recipe"} = post_fixture(%{user_id: user.id})
    end
  end

  describe "update_post/2 with recipe_first" do
    test "legacy photo posts stay editable while the flag is on", %{
      user: user,
      original: original
    } do
      legacy = post_fixture(%{user_id: user.id, type: "post"})
      flag_on(original)

      assert {:ok, %{caption: "edited"}} = Posts.update_post(legacy, %{caption: "edited"})
    end
  end
end
