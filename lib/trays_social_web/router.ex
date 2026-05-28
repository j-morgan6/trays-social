defmodule TraysSocialWeb.Router do
  use TraysSocialWeb, :router

  import TraysSocialWeb.UserAuth
  import ErrorTracker.Web.Router
  import Phoenix.LiveDashboard.Router

  # D57: hardened CSP. Compared to the previous version:
  #   - `'unsafe-inline'` removed from style-src. Tailwind generates static
  #     CSS at build time, so no inline <style> blocks should be needed.
  #     If a future feature genuinely requires inline styles, switch to a
  #     per-request nonce rather than re-allowing unsafe-inline globally.
  #   - `base-uri 'self'` — without this, an injected <base href="…"> can
  #     rewrite every relative URL on the page. Doesn't fall back to
  #     default-src.
  #   - `form-action 'self'` — without this, an injected <form> can post
  #     credentials cross-origin. Doesn't fall back to default-src.
  #   - `frame-ancestors 'self'` — defends against clickjacking. XFO already
  #     covers this for older browsers; the CSP directive is the modern path.
  @csp_header "default-src 'self'; " <>
                "script-src 'self' 'wasm-unsafe-eval'; " <>
                "style-src 'self'; " <>
                "img-src 'self' data: blob: https:; " <>
                "connect-src 'self' wss:; " <>
                "base-uri 'self'; " <>
                "form-action 'self'; " <>
                "frame-ancestors 'self'"

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TraysSocialWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{"content-security-policy" => @csp_header}

    plug :fetch_current_scope_for_user
  end

  # D64: same as :browser but skips :protect_from_forgery. Used for the
  # Apple Sign In form_post callback — Apple POSTs from their own origin
  # without a CSRF token. Replay protection comes from the signed state
  # parameter validated inside the controller, not from CSRF.
  pipeline :browser_no_csrf do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TraysSocialWeb.Layouts, :root}

    plug :put_secure_browser_headers, %{"content-security-policy" => @csp_header}

    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TraysSocialWeb.API.AuthPlug
  end

  pipeline :api_rate_limit_login do
    plug TraysSocialWeb.API.RateLimitPlug, max_requests: 10, interval_ms: 60_000
  end

  pipeline :api_rate_limit_register do
    plug TraysSocialWeb.API.RateLimitPlug, max_requests: 5, interval_ms: 60_000
  end

  pipeline :api_require_confirmed do
    plug TraysSocialWeb.API.RequireConfirmedPlug
  end

  pipeline :api_rate_limit_reports do
    plug TraysSocialWeb.API.RateLimitPlug, max_requests: 10, interval_ms: 3_600_000
  end

  # Generous per-user/IP limit for read and account endpoints.
  pipeline :api_rate_limit_read do
    plug TraysSocialWeb.API.RateLimitPlug, max_requests: 300, interval_ms: 60_000
  end

  # Stricter limit for write actions (likes, comments, follows, bookmarks, posts).
  pipeline :api_rate_limit_write do
    plug TraysSocialWeb.API.RateLimitPlug, max_requests: 60, interval_ms: 60_000
  end

  # Very strict limit for resend confirmation to prevent email abuse.
  pipeline :api_rate_limit_resend do
    plug TraysSocialWeb.API.RateLimitPlug, max_requests: 3, interval_ms: 600_000
  end

  # W117: MetricKit ingest. Apple delivers at most one diagnostic
  # payload per device per day, so 1/min/user is generous — the limit
  # is here to absorb retry storms from a misbehaving client, not to
  # gate normal traffic.
  pipeline :api_rate_limit_diagnostics do
    plug TraysSocialWeb.API.RateLimitPlug, max_requests: 1, interval_ms: 60_000
  end

  # W106: webhook ingress from third-party services (Resend, etc.). Three
  # deliberate differences from :api:
  #   - no CSRF (third-party origin can't carry our CSRF token)
  #   - no rate limit (5xx retries from the sender need to be captured)
  #   - no auth plug (authentication is per-controller via signed payload)
  pipeline :webhook do
    plug :accepts, ["json"]
  end

  # Health check — no auth, no SSL redirect
  scope "/", TraysSocialWeb do
    pipe_through :api
    get "/health", HealthController, :check
  end

  # Apple Universal Links discovery — Apple CDN fetches this and caches.
  # Must serve as application/json, no redirects, no auth.
  scope "/.well-known", TraysSocialWeb do
    pipe_through :api
    get "/apple-app-site-association", WellKnownController, :aasa
  end

  # Legal pages — public, indexable, no auth, cache-friendly
  scope "/", TraysSocialWeb do
    pipe_through :browser

    get "/privacy", LegalController, :privacy
    get "/terms", LegalController, :terms
    get "/community-guidelines", LegalController, :community_guidelines
  end


  # API v1 — unauthenticated routes
  scope "/api/v1/auth", TraysSocialWeb.API.V1, as: :api_v1_auth do
    pipe_through [:api, :api_rate_limit_register]
    post "/register", AuthController, :register
  end

  scope "/api/v1/auth", TraysSocialWeb.API.V1, as: :api_v1_auth do
    pipe_through [:api, :api_rate_limit_login]
    post "/login", AuthController, :login
    post "/apple", AuthController, :apple
    # W105: biometric unlock exchanges a stored refresh token for a fresh
    # API bearer. Unauthenticated — the refresh token IS the credential.
    # Pipes through the login rate-limit so the endpoint isn't a free
    # credential-stuffing oracle on stolen refresh tokens.
    post "/biometric-exchange", AuthController, :biometric_exchange
    # Confirm a registration token via Universal Link. iOS captures the link
    # tap, extracts the token, and POSTs it here so the user record's
    # `confirmed_at` is set. Web fallback (Safari users without the app)
    # continues to use the LiveView confirmation flow at /users/confirm/<token>.
    post "/confirm", AuthController, :confirm
  end

  # Resend confirmation — very strict limit, separate scope
  scope "/api/v1", TraysSocialWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_auth, :api_rate_limit_resend]

    post "/auth/resend-confirmation", AuthController, :resend_confirmation
  end

  # API v1 — authenticated routes (read-only + account management)
  scope "/api/v1", TraysSocialWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_auth, :api_rate_limit_read]

    delete "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me
    put "/auth/me", AuthController, :update_me
    delete "/auth/me", AuthController, :delete_me
    # W105: post-login opt-in to biometric. Authenticated with the current
    # API bearer; returns a refresh token the iOS client stores in
    # biometric-gated Keychain.
    post "/auth/refresh-tokens", AuthController, :create_refresh_token

    get "/feed", FeedController, :index
    get "/posts/trending", PostController, :trending
    get "/posts/:id", PostController, :show

    get "/posts/:post_id/comments", CommentController, :index

    get "/search", SearchController, :index

    get "/notifications", NotificationController, :index
    post "/notifications/read", NotificationController, :mark_read

    get "/bookmarks", BookmarkController, :index

    post "/devices", DeviceController, :create
    delete "/devices/:token", DeviceController, :delete

    get "/blocked-users", UserController, :list_blocked_users
    get "/muted-keywords", UserController, :muted_keywords
    put "/muted-keywords", UserController, :update_muted_keywords

    get "/users/:username", UserController, :show
    get "/users/:username/posts", UserController, :posts
    get "/users/:username/followers", UserController, :followers
    get "/users/:username/following", UserController, :following
  end

  # API v1 — authenticated + confirmed email required (write actions)
  scope "/api/v1", TraysSocialWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_auth, :api_require_confirmed, :api_rate_limit_write]

    post "/uploads", UploadController, :create
    post "/posts", PostController, :create
    delete "/posts/:id", PostController, :delete

    post "/posts/:post_id/like", LikeController, :create
    delete "/posts/:post_id/like", LikeController, :delete

    post "/posts/:post_id/comments", CommentController, :create
    delete "/comments/:id", CommentController, :delete

    post "/bookmarks/:post_id", BookmarkController, :create
    delete "/bookmarks/:post_id", BookmarkController, :delete

    post "/users/:username/follow", UserController, :follow
    delete "/users/:username/follow", UserController, :unfollow

    post "/users/:username/block", UserController, :block
    delete "/users/:username/block", UserController, :unblock

    # W123: in-app feedback ingest. Authenticated; uses the write
    # bucket because human-typed feedback is low-frequency relative
    # to like/comment writes.
    post "/feedback", FeedbackController, :create
  end

  # API v1 — reports (rate limited separately)
  scope "/api/v1", TraysSocialWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_auth, :api_require_confirmed, :api_rate_limit_reports]

    post "/reports", ReportController, :create
  end

  # W117: MetricKit ingest from iOS clients. Auth required so we can
  # correlate crashes to users; not confirmation-gated because a user
  # may need to send a diagnostic before confirming their email.
  scope "/api/v1", TraysSocialWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_auth, :api_rate_limit_diagnostics]

    post "/ios_diagnostics", IosDiagnosticController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:trays_social, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: TraysSocialWeb.Telemetry,
        ecto_repos: [TraysSocial.Repo]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Admin routes — require authenticated user AND is_admin=true on the user
  # record. Non-admins receive 404 (not 403/redirect) so admin routes are
  # not enumerable.
  scope "/admin", TraysSocialWeb.Admin do
    pipe_through [:browser, :require_authenticated_user, TraysSocialWeb.Plugs.RequireAdmin]

    live "/reports", ReportsLive, :index
    live "/email-events", EmailEventsLive, :index
    live "/ios-crashes", IosCrashesLive, :index
    live "/ios-crashes/:id", IosCrashesLive, :show
    live "/feedback", FeedbackLive, :index
    live "/feedback/:id", FeedbackLive, :show
  end

  # W106: Resend webhook receiver. Signature is verified inside the
  # controller using the raw body preserved by Plugs.RawBodyReader. The
  # :webhook pipeline intentionally skips CSRF + rate limit + auth.
  scope "/webhooks", TraysSocialWeb.Webhooks do
    pipe_through :webhook

    post "/resend", ResendController, :receive
  end

  # ErrorTracker dashboard — same admin gate as the /admin/reports scope.
  # Uses ErrorTracker's own Live router macro which mounts the dashboard
  # at the given path. Captured exceptions persist to TraysSocial.Repo
  # (see config/config.exs ErrorTracker config).
  scope "/admin", TraysSocialWeb do
    pipe_through [:browser, :require_authenticated_user, TraysSocialWeb.Plugs.RequireAdmin]

    error_tracker_dashboard "/errors"
  end

  # Phoenix LiveDashboard — runtime stats (process tree, memory, telemetry,
  # ETS, etc.) for the operator. Same admin gate. Separate scope from the
  # error_tracker dashboard because each macro that opens its own
  # live_session needs its own scope to avoid session_name collisions.
  # Note: a dev-only mount at /dev/dashboard remains below for local
  # convenience without requiring an admin login.
  scope "/admin", TraysSocialWeb do
    pipe_through [:browser, :require_authenticated_user, TraysSocialWeb.Plugs.RequireAdmin]

    live_dashboard "/dashboard",
      metrics: TraysSocialWeb.Telemetry,
      ecto_repos: [TraysSocial.Repo],
      live_session_name: :admin_live_dashboard
  end

  ## Authentication routes

  scope "/", TraysSocialWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", TraysSocialWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Primary content surfaces — D60: gated to logged-in users so anonymous
    # visitors don't see other users' recipes/profiles. /users/confirm/<token>,
    # /privacy, /terms, /.well-known/*, and /api/* remain publicly accessible
    # (intentional — see scopes above and the api_v1_auth scope).
    live "/", FeedLive.Index, :index
    live "/explore", ExploreLive.Index, :index
    live "/@:username", ProfileLive.Show, :show
    live "/@:username/followers", FollowersLive.Show, :followers
    live "/@:username/following", FollowersLive.Show, :following

    live "/welcome", WelcomeLive.Index, :index
    live "/posts/new", PostLive.New, :new
    live "/my-tray", MyTrayLive.Index, :index
    live "/users/settings", SettingsLive.Index, :index
    live "/notifications", NotificationsLive.Index, :index

    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", TraysSocialWeb do
    pipe_through [:browser]

    live "/posts/:id", PostLive.Show, :show
  end

  scope "/", TraysSocialWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
    get "/users/confirm/:token", UserConfirmationController, :confirm
    post "/users/confirmation/resend", UserConfirmationController, :resend

    # D64: Sign in with Apple — start initiates Apple's authorize redirect.
    # Callback is in the :browser_no_csrf pipeline below (Apple form_post
    # comes from a third-party origin without our CSRF token).
    get "/auth/apple/start", AppleSignInController, :start
  end

  scope "/", TraysSocialWeb do
    pipe_through [:browser_no_csrf]

    post "/auth/apple/callback", AppleSignInController, :callback
  end
end
