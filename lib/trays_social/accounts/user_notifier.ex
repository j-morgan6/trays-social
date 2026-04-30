defmodule TraysSocial.Accounts.UserNotifier do
  import Swoosh.Email

  alias TraysSocial.Accounts.User
  alias TraysSocial.Mailer

  # Brand color (Modern Kitchen primary green). Used for the CTA button background.
  @primary_color "#1B5E20"

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(
      user.email,
      "Update your Trays email",
      text_body_for_update(user.email, url),
      html_email_body(
        "Confirm your new email",
        "Tap the button below to confirm the email change on your Trays account. " <>
          "If you didn't request this, ignore this message — nothing will change.",
        "Confirm new email",
        url
      )
    )
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(
      user.email,
      "Log in to Trays",
      text_body_for_magic_link(user.email, url),
      html_email_body(
        "Log in to your Trays account",
        "Tap the button below to log in. The link is single-use and expires after a short window. " <>
          "If you didn't request this, you can safely ignore the email.",
        "Log in",
        url
      )
    )
  end

  @doc """
  Deliver instructions to confirm a user's email address.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(
      user.email,
      "Confirm your Trays account",
      text_body_for_confirmation(user.email, url),
      html_email_body(
        "Welcome to Trays",
        "Confirm your email address to finish setting up your account and start sharing recipes.",
        "Confirm email",
        url
      )
    )
  end

  # Delivers the email using the application mailer with both plain-text and HTML bodies.
  defp deliver(recipient, subject, text, html) do
    from_email = Application.get_env(:trays_social, :mailer_from_email, "noreply@trays.social")

    email =
      new()
      |> to(recipient)
      |> from({"Trays", from_email})
      |> subject(subject)
      |> text_body(text)
      |> html_body(html)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # Plain-text bodies. The URL appears on its own line so test/support helpers
  # (extract_user_token/1) can locate it via simple line splitting.

  defp text_body_for_confirmation(email, url) do
    """
    Hi #{email},

    Welcome to Trays. Confirm your email address to finish setting up your account.

    Open this link to confirm:

    #{url}

    If you didn't create a Trays account, you can safely ignore this email.

    — The Trays team
    """
  end

  defp text_body_for_magic_link(email, url) do
    """
    Hi #{email},

    Open this link to log in to Trays. It's single-use and expires after a short window.

    #{url}

    If you didn't request a login email, you can safely ignore this message.

    — The Trays team
    """
  end

  defp text_body_for_update(email, url) do
    """
    Hi #{email},

    Open this link to confirm the email change on your Trays account.

    #{url}

    If you didn't request this change, ignore this email — nothing will be updated.

    — The Trays team
    """
  end

  # HTML body shell. Inline styles only — many email clients strip <style> blocks.
  # Table-based layout for legacy client compatibility.
  defp html_email_body(heading, intro, cta_label, url) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <meta name="supported-color-schemes" content="light dark">
        <title>#{html_escape(heading)}</title>
      </head>
      <body style="margin:0;padding:0;background:#f4f4f4;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1f2937;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f4f4f4;">
          <tr>
            <td align="center" style="padding:32px 16px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px;background:#ffffff;border-radius:12px;overflow:hidden;">
                <tr>
                  <td style="padding:24px 32px;background:#{@primary_color};">
                    <span style="font-size:24px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">Trays</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:32px;">
                    <h1 style="margin:0 0 16px;font-size:22px;line-height:1.3;font-weight:600;color:#1f2937;">#{html_escape(heading)}</h1>
                    <p style="margin:0 0 24px;font-size:16px;line-height:1.5;color:#4b5563;">#{html_escape(intro)}</p>
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="center" bgcolor="#{@primary_color}" style="border-radius:8px;">
                          <a href="#{html_attr(url)}" style="display:inline-block;padding:14px 28px;font-size:16px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:8px;">#{html_escape(cta_label)}</a>
                        </td>
                      </tr>
                    </table>
                    <p style="margin:24px 0 0;font-size:14px;line-height:1.5;color:#6b7280;">If the button doesn't work, copy and paste this link into your browser:</p>
                    <p style="margin:8px 0 0;font-size:13px;line-height:1.5;color:#6b7280;word-break:break-all;"><a href="#{html_attr(url)}" style="color:#{@primary_color};text-decoration:underline;">#{html_escape(url)}</a></p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:20px 32px;background:#f9fafb;border-top:1px solid #e5e7eb;">
                    <p style="margin:0;font-size:12px;line-height:1.5;color:#6b7280;text-align:center;">Trays — find something to eat. <br>You're receiving this because someone (probably you) used this email to register or update an account on Trays.</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end

  # Minimal HTML escaping for text content. Adequate for our trusted inputs
  # (email addresses, app-generated URLs, fixed copy).
  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp html_attr(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
