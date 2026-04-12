import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/trays_social start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :trays_social, TraysSocialWeb.Endpoint, server: true
end

config :trays_social, TraysSocialWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :trays_social, TraysSocial.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      For example: trays-social-review.fly.dev
      """

  config :trays_social, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Storage backend — S3 for production, local for dev/test
  if s3_bucket = System.get_env("S3_BUCKET") do
    config :trays_social,
      storage_backend: :s3,
      s3_bucket: s3_bucket,
      s3_base_url: System.get_env("S3_BASE_URL") || "https://#{s3_bucket}.fly.storage.tigris.dev"

    config :ex_aws,
      access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      region: System.get_env("AWS_REGION", "auto")

    if s3_endpoint = System.get_env("S3_ENDPOINT") do
      config :ex_aws, :s3,
        scheme: "https://",
        host: s3_endpoint
    end
  else
    # Fallback to local uploads with optional custom dir
    if upload_dir = System.get_env("UPLOAD_DIR") do
      config :trays_social, :upload_dir, upload_dir
    end
  end

  # APNs push notifications (requires Apple Developer Account .p8 key)
  if apns_key_id = System.get_env("APNS_KEY_ID") do
    config :trays_social,
      push_notifications_enabled: true,
      apns_topic: System.get_env("APNS_TOPIC", "com.trays.social")

    config :pigeon, :apns,
      key_id: apns_key_id,
      team_id: System.get_env("APNS_TEAM_ID"),
      key: System.get_env("APNS_P8_KEY")
  end

  config :trays_social, TraysSocialWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :trays_social, TraysSocialWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :trays_social, TraysSocialWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # Configuring the mailer
  # Resend is the default adapter. Set RESEND_API_KEY and MAILER_FROM_EMAIL
  # as Fly secrets: fly secrets set RESEND_API_KEY=re_xxx MAILER_FROM_EMAIL=noreply@trays.social
  resend_api_key =
    System.get_env("RESEND_API_KEY") ||
      raise """
      environment variable RESEND_API_KEY is missing.
      Get one at https://resend.com/api-keys
      """

  mailer_from_email =
    System.get_env("MAILER_FROM_EMAIL") ||
      raise """
      environment variable MAILER_FROM_EMAIL is missing.
      For example: noreply@trays.social
      """

  config :trays_social, TraysSocial.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: resend_api_key

  config :trays_social, :mailer_from_email, mailer_from_email
end
