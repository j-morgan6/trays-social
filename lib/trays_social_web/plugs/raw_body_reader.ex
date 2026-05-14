defmodule TraysSocialWeb.Plugs.RawBodyReader do
  @moduledoc """
  Plug.Parsers body reader that preserves the raw request body in
  `conn.assigns[:raw_body]` while still letting downstream parsers (JSON,
  urlencoded, etc.) consume it.

  Used by the `:webhook` pipeline so the Resend webhook controller can
  verify the HMAC signature against the exact bytes the sender signed.
  Without this, Plug.Conn.read_body/2 consumes the body and the signature
  check fails because the JSON-decoded map is not the same bytes.

  Reference: https://hexdocs.pm/plug/Plug.Parsers.html#module-custom-body-reader
  """

  @doc false
  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
    end
  end
end
