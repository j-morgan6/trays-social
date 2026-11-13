defmodule TraysSocialWeb.UserResetPasswordController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts
  alias TraysSocialWeb.AuthRateLimit
  alias TraysSocialWeb.UserAuth

  # One message for an unknown, expired or already used link, so the page
  # never says which.
  @invalid_link "The reset link is invalid or it has expired."

  @email_required "Enter your email address."

  # W252: the sign-in pages show info and error flashes in place (the amber
  # callout above the button), so the root layout leaves them out of its
  # toast group on these pages.
  plug :inline_flash
  plug :no_referrer when action in [:edit, :update]
  plug :fetch_user_by_reset_token when action in [:edit, :update]

  def new(conn, _params) do
    render_request_form(conn, Phoenix.Component.to_form(%{}, as: "user"))
  end

  @doc """
  Asks for a reset email (W255), the web twin of
  `POST /api/v1/auth/reset-password`. Every non-blank email gets the same
  Check your email page, whether the account exists, the request is rate
  limited or the mailer fails; only the side effect differs. Resend posts
  here too, so it goes through the same limiter.
  """
  def create(conn, params) do
    typed = email_param(params)

    case String.trim(typed) do
      "" ->
        form =
          Phoenix.Component.to_form(%{"email" => typed},
            as: "user",
            errors: [email: {@email_required, []}]
          )

        render_request_form(conn, form)

      email ->
        # Trim before keying the limiter, so padded variants share a bucket.
        if AuthRateLimit.check_password_reset_request(conn, email) == :ok do
          Accounts.request_password_reset(email, &url(~p"/users/reset-password/#{&1}"))
        end

        render(conn, :new,
          form: Phoenix.Component.to_form(%{}, as: "user"),
          sent_to: email,
          page_title: "Check your email"
        )
    end
  end

  defp render_request_form(conn, form) do
    render(conn, :new, form: form, sent_to: nil, page_title: "Reset your password")
  end

  defp email_param(%{"user" => %{"email" => email}}) when is_binary(email), do: email
  defp email_param(_params), do: ""

  def edit(conn, _params) do
    form =
      conn.assigns.user
      |> Accounts.change_user_password(%{}, hash_password: false)
      |> Phoenix.Component.to_form(as: "user")

    render(conn, :edit, form: form)
  end

  def update(conn, params) do
    # Both keys default to "": Ecto's validate_confirmation only runs when the
    # confirmation param is present, so a request that leaves it out must not
    # skip the match check.
    user_params =
      Map.merge(
        %{"password" => "", "password_confirmation" => ""},
        Map.take(user_params(params), ~w(password password_confirmation))
      )

    case Accounts.reset_user_password(conn.assigns.user, user_params) do
      {:ok, {_user, expired_tokens}} ->
        UserAuth.disconnect_sessions(expired_tokens)

        conn
        |> put_flash(:info, "Your password has been reset. Log in with your new password.")
        |> redirect(to: ~p"/users/log-in")

      {:error, changeset} ->
        render(conn, :edit, form: Phoenix.Component.to_form(changeset, as: "user"))
    end
  end

  defp user_params(%{"user" => %{} = user_params}), do: user_params
  defp user_params(_params), do: %{}

  defp fetch_user_by_reset_token(conn, _opts) do
    token = conn.params["token"]

    if user = Accounts.get_user_by_reset_password_token(token) do
      conn
      |> assign(:user, user)
      |> assign(:token, token)
    else
      conn
      |> put_flash(:error, @invalid_link)
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  # The page URL carries the reset credential, so no request made from it
  # (the form's PUT, the Log in link, a redirect) may send it on as Referer.
  defp no_referrer(conn, _opts), do: put_resp_header(conn, "referrer-policy", "no-referrer")

  defp inline_flash(conn, _opts), do: assign(conn, :inline_flash, true)
end
