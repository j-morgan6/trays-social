defmodule TraysSocial.MailerTestHelpers do
  @moduledoc """
  Shared helpers for exercising the mailer-failure branches (D63, D115, D117).

  `with_failing_mailer/1` swaps `TraysSocial.Mailer` to `FailingAdapter`, which
  always returns `{:error, :simulated_mailer_failure}`, for the duration of the
  given function, then restores the original config.

  It changes global Application env, so any test module that uses it must be
  `async: false`.
  """

  defmodule FailingAdapter do
    @moduledoc "A Swoosh adapter that always fails, without a network call."
    @behaviour Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: {:error, :simulated_mailer_failure}

    @impl true
    def validate_config(_config), do: :ok
  end

  def with_failing_mailer(fun) do
    original = Application.get_env(:trays_social, TraysSocial.Mailer)
    Application.put_env(:trays_social, TraysSocial.Mailer, adapter: FailingAdapter)

    try do
      fun.()
    after
      if original == nil do
        Application.delete_env(:trays_social, TraysSocial.Mailer)
      else
        Application.put_env(:trays_social, TraysSocial.Mailer, original)
      end
    end
  end
end
