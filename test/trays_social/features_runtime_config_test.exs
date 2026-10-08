defmodule TraysSocial.FeaturesRuntimeConfigTest do
  # async: false: sets OS environment variables, which are global to the VM.
  #
  # Evaluates the real config/runtime.exs under env: :prod so the
  # FEATURES_RECIPE_FIRST parsing is tested where it lives, not a copy of it.
  # Config.Reader returns the config as data; nothing is written to the
  # application env.
  use ExUnit.Case, async: false

  @runtime_config Path.expand("../../config/runtime.exs", __DIR__)

  # Placeholder values for the variables the prod block raises without. None
  # of them is a real endpoint or secret; the test only reads :features.
  @prod_required %{
    "DATABASE_URL" => "ecto://placeholder@localhost/placeholder",
    "SECRET_KEY_BASE" => String.duplicate("x", 64),
    "PHX_HOST" => "localhost",
    "RESEND_API_KEY" => "placeholder",
    "MAILER_FROM_EMAIL" => "noreply@localhost"
  }

  @flag_var "FEATURES_RECIPE_FIRST"

  setup do
    vars = [@flag_var | Map.keys(@prod_required)]
    saved = Map.new(vars, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {var, nil} -> System.delete_env(var)
        {var, value} -> System.put_env(var, value)
      end)
    end)

    System.put_env(@prod_required)
    :ok
  end

  defp prod_recipe_first(env_value) do
    case env_value do
      nil -> System.delete_env(@flag_var)
      value -> System.put_env(@flag_var, value)
    end

    @runtime_config
    |> Config.Reader.read!(env: :prod, target: :host)
    |> Keyword.fetch!(:trays_social)
    |> Keyword.fetch!(:features)
    |> Keyword.fetch!(:recipe_first)
  end

  test "FEATURES_RECIPE_FIRST unset keeps the config.exs default (off)" do
    assert prod_recipe_first(nil) == false
  end

  test "FEATURES_RECIPE_FIRST set to 1, true or TRUE turns the flag on" do
    for value <- ["1", "true", "TRUE"] do
      assert prod_recipe_first(value) == true, "expected #{inspect(value)} to enable recipe_first"
    end
  end

  test "FEATURES_RECIPE_FIRST set to a non-true value leaves the flag off" do
    for value <- ["0", "false", "yes", "on", "True", " true", ""] do
      assert prod_recipe_first(value) == false,
             "expected #{inspect(value)} to leave recipe_first off"
    end
  end
end
