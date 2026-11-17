defmodule TraysSocial.MixProject do
  use Mix.Project

  def project do
    [
      app: :trays_social,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: test_coverage()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {TraysSocial.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_psql_extras, "~> 0.8"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      # Pinned to 0.6.x: "~> 0.5" let deps.update float to 0.7, which breaks
      # APIs. 0.6 carries the advisory fixes, and AppleAuth's JWKS fetch relies
      # on the JSON body being auto-decoded (compression is opt-in since 0.6.1).
      {:req, "~> 0.6.1"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:earmark, "~> 1.4"},
      {:bandit, "~> 1.5"},
      # Direct dep so ex_aws (Tigris S3 photo storage) gets an HTTP client: its
      # hackney dependency is optional. 4.0.1+ patches the hackney advisories.
      # No override: every dependent must accept 4.x on its own, so an
      # incompatible bump fails resolution instead of hiding (ex_aws must be
      # 2.7+, whose adapter matches hackney 4's response shape).
      {:hackney, "~> 4.0"},
      {:mogrify, "~> 0.9"},
      {:hammer, "~> 6.2"},
      # D45: parses X-Forwarded-For from trusted proxies and rewrites
      # conn.remote_ip so RateLimitPlug buckets the real client IP rather
      # than the Fly/Cloudflare/ALB egress address.
      {:remote_ip, "~> 1.2"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7"},
      {:assent, "~> 0.2"},
      # 2.1 talks to APNs over Mint, dropping httpoison and kadabra (and with
      # them the last dependent that capped hackney below 2.0).
      {:pigeon, "~> 2.1"},
      {:joken, "~> 2.6"},
      {:error_tracker, "~> 0.9"},
      {:tidewave, "~> 0.5", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp test_coverage do
    [
      # Ratchet: raise as coverage grows — but keep it passing, or local
      # `mix test` exits non-zero on every run and the signal dies (W171).
      summary: [threshold: 74],
      ignore_modules: [
        Inspect.TraysSocial.Accounts.User,
        TraysSocial,
        TraysSocial.AccountsFixtures,
        TraysSocial.AppStoreFixtures,
        TraysSocial.Application,
        TraysSocial.DataCase,
        TraysSocial.Mailer,
        TraysSocial.PostsFixtures,
        TraysSocial.Repo,
        TraysSocialWeb,
        TraysSocialWeb.ConnCase,
        TraysSocialWeb.CoreComponents,
        TraysSocialWeb.Endpoint,
        TraysSocialWeb.ErrorHTML,
        TraysSocialWeb.ErrorJSON,
        TraysSocialWeb.Gettext,
        TraysSocialWeb.Layouts,
        TraysSocialWeb.PageController,
        TraysSocialWeb.PageHTML,
        TraysSocialWeb.Router,
        TraysSocialWeb.Telemetry,
        TraysSocialWeb.UserRegistrationHTML,
        TraysSocialWeb.UserSessionHTML,
        TraysSocialWeb.UserSettingsHTML,
        TraysSocial.Uploads.ImageProcessor
      ]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test --cover"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind trays_social", "esbuild trays_social"],
      "assets.deploy": [
        "tailwind trays_social --minify",
        "esbuild trays_social --minify",
        "phx.digest"
      ],
      # GHSA-52mm-h59v-f3c7 (earmark: unescaped HTML attribute values) has no
      # fix; earmark is retired. Only LegalDocParser calls it, at compile time,
      # on our own priv/legal/*.md, never on user input. Scoped to this one ID:
      # remove the ignore when earmark is replaced (e.g. by MDEx).
      security: [
        "deps.audit --ignore-advisory-ids GHSA-52mm-h59v-f3c7",
        "sobelow --config"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "test",
        "credo --strict",
        "security"
      ]
    ]
  end
end
