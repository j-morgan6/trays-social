# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :trays_social, :scopes,
  user: [
    default: true,
    module: TraysSocial.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: TraysSocial.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :trays_social,
  ecto_repos: [TraysSocial.Repo],
  generators: [timestamp_type: :utc_datetime],
  upload_dir: "priv/static/uploads"

# Configure the endpoint
config :trays_social, TraysSocialWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TraysSocialWeb.ErrorHTML, json: TraysSocialWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TraysSocial.PubSub,
  live_view: [signing_salt: "XS57MxJf"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :trays_social, TraysSocial.Mailer, adapter: Swoosh.Adapters.Local
config :trays_social, :mailer_from_email, "noreply@trays.social"

# Default admin allowlist; can be overridden by ADMIN_EMAILS env var in
# config/runtime.exs. Emails are compared case-insensitively. Apple Sign
# In with a private relay address will NOT match — operator must register
# via email/password OR manually flip is_admin in the DB.
config :trays_social, :admin_emails, ["jsm10242000@gmail.com"]

# G38 monetization feature flags. All OFF by default — the entire
# monetization surface (in-app ads, web ads, paid tier) ships inert until a
# deploy flips a flag here or via the FEATURES_* env overrides in
# config/runtime.exs. See TraysSocial.Monetization. NORTH STAR: these gate
# ad slots and the paid utility tier, never recipe content.
config :trays_social, :features,
  in_app_ads: false,
  web_ads: false,
  paid_tier: false

# W174 StoreKit 2 / App Store Server Notifications V2.
#
# product_ids is the allowlist a verified transaction must match — a validly
# Apple-signed subscription for some OTHER product must never grant Plus.
# These MUST match the product identifiers created in the "Trays Plus"
# subscription group in App Store Connect ($3.99/mo, $29.99/yr, 7-day trial).
# Overridable in prod via APP_STORE_PRODUCT_IDS / APP_STORE_ENVIRONMENTS.
config :trays_social, :app_store,
  product_ids: ["trays.plus.monthly", "trays.plus.yearly"],
  environments: ["Sandbox"]

# W174: set explicitly. AppleAuth previously read this key with a hardcoded
# "com.trays.social" default that no config file ever set, so the StoreKit
# bundle-id check would have passed only by accident. Sign in with Apple and
# StoreKit validate the same bundle id by definition — one key, not two, so
# they cannot silently diverge.
config :trays_social, :apple_bundle_id, "com.trays.social"

# W159 web ad network wiring. Both values stay nil until the ad-network
# account exists AND the router @csp_header is amended in a follow-up to
# allow the network's origins — with nil script_url the AdSlot JS hook is a
# no-op and the sponsored slots render first-party house copy only.
# Overridable in prod via WEB_ADS_SCRIPT_URL / WEB_ADS_SITE_ID (runtime.exs).
config :trays_social, :web_ads,
  script_url: nil,
  site_id: nil

# Configure ErrorTracker — captures unhandled exceptions and persists them
# to the trays_social Postgres database. Self-hosted, no third-party calls.
config :error_tracker, repo: TraysSocial.Repo, otp_app: :trays_social

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  trays_social: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  trays_social: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Hammer rate limiting
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 300_000, cleanup_interval_ms: 600_000]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
