defmodule TraysSocialWeb.Plugs.UploadServing do
  @moduledoc """
  Serves uploaded files from the configured upload directory.

  In development, uploads are in priv/static/uploads (also served by Plug.Static).
  In production on Fly.io, uploads are on a persistent volume at UPLOAD_DIR.
  """
  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(%{path_info: ["uploads", filename]} = conn, _opts) when is_binary(filename) do
    serve_file(conn, filename)
  end

  def call(conn, _opts), do: conn

  defp serve_file(conn, filename) do
    # Prevent path traversal
    if String.contains?(filename, "..") or String.contains?(filename, "/") do
      conn
    else
      file_path = Path.join(TraysSocial.Uploads.Photo.upload_dir(), filename)

      if File.regular?(file_path) do
        content_type = MIME.from_path(file_path)

        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000")
        |> send_file(200, file_path)
        |> halt()
      else
        conn
      end
    end
  end
end
