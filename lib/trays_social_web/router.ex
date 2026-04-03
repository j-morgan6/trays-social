defmodule TraysSocialWeb.Router do
  use TraysSocialWeb, :router

  import TraysSocialWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TraysSocialWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; connect-src 'self' wss:"
    }

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

  # Health check — no auth, no SSL redirect
  scope "/", TraysSocialWeb do
    pipe_through :api
    get "/health", HealthController, :check
  end

  scope "/", TraysSocialWeb do
    pipe_through :browser

    live "/", FeedLive.Index, :index
    live "/explore", ExploreLive.Index, :index
    live "/@:username", ProfileLive.Show, :show
  end

  # API v1 — unauthenticated routes
  scope "/api/v1", TraysSocialWeb.API.V1, as: :api_v1 do
    pipe_through :api
  end

  # API v1 — authenticated routes
  scope "/api/v1", TraysSocialWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    post "/uploads", UploadController, :create
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

      live_dashboard "/dashboard", metrics: TraysSocialWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TraysSocialWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", TraysSocialWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/posts/new", PostLive.New, :new
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
  end
end
