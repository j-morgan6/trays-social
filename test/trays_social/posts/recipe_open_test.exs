defmodule TraysSocial.Posts.RecipeOpenTest do
  use TraysSocial.DataCase, async: true

  import Ecto.Query
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Posts
  alias TraysSocial.Posts.RecipeOpen
  alias TraysSocial.Repo

  describe "record_recipe_open/2" do
    test "records the first open" do
      user = user_fixture()
      post = post_fixture(%{user_id: user_fixture().id})

      assert {:ok, %RecipeOpen{} = open} = Posts.record_recipe_open(user.id, post.id)
      assert open.user_id == user.id
      assert open.post_id == post.id
      assert :second |> DateTime.utc_now() |> DateTime.diff(open.last_opened_at, :second) < 5
    end

    test "a repeat open updates the same row" do
      user = user_fixture()
      post = post_fixture(%{user_id: user_fixture().id})

      assert {:ok, _} = Posts.record_recipe_open(user.id, post.id)
      old = :second |> DateTime.utc_now() |> DateTime.add(-30, :day)
      Repo.update_all(RecipeOpen, set: [last_opened_at: old])

      assert {:ok, _} = Posts.record_recipe_open(user.id, post.id)

      assert [row] = RecipeOpen |> where([o], o.user_id == ^user.id) |> Repo.all()
      assert DateTime.compare(row.last_opened_at, old) == :gt
    end

    test "returns an error changeset for a post that does not exist" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} = Posts.record_recipe_open(user.id, -1)
    end
  end
end
