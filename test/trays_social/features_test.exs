defmodule TraysSocial.FeaturesTest do
  # async: false: mutates the global :features config.
  use ExUnit.Case, async: false

  alias TraysSocial.Features

  setup do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    %{original: original}
  end

  test "recipe_first is off by default" do
    refute Features.recipe_first?()
    assert Features.client_flags().recipe_first == false
  end

  test "recipe_first follows the :features config", %{original: original} do
    Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))
    assert Features.recipe_first?()
    assert Features.client_flags().recipe_first == true
  end

  test "recipe_first is off when the key is missing from :features", %{original: original} do
    Application.put_env(:trays_social, :features, Keyword.delete(original, :recipe_first))
    refute Features.recipe_first?()
    assert Features.client_flags().recipe_first == false
  end

  test "client_flags carries exactly recipe_first and paid_tier", %{original: original} do
    Application.put_env(
      :trays_social,
      :features,
      original |> Keyword.put(:recipe_first, false) |> Keyword.put(:paid_tier, false)
    )

    assert Features.client_flags() == %{recipe_first: false, paid_tier: false}
  end

  test "paid_tier follows the :features config", %{original: original} do
    Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, true))
    assert Features.client_flags().paid_tier == true

    Application.put_env(:trays_social, :features, Keyword.delete(original, :paid_tier))
    assert Features.client_flags().paid_tier == false
  end

  test "only the literal true enables recipe_first", %{original: original} do
    for value <- ["true", "1", 1, :yes, nil] do
      Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, value))
      refute Features.recipe_first?(), "expected #{inspect(value)} to leave recipe_first off"
    end
  end
end
