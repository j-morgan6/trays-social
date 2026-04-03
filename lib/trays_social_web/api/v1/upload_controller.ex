defmodule TraysSocialWeb.API.V1.UploadController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Uploads.Photo

  def create(conn, %{"photo" => %Plug.Upload{} = upload}) do
    case Photo.store(upload) do
      {:ok, url} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{url: url}})

      {:error, :invalid_extension} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{field: "photo", message: "invalid file type. Allowed: #{Enum.join(Photo.allowed_extensions(), ", ")}"}]})

      {:error, :file_too_large} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{field: "photo", message: "file too large. Maximum: #{div(Photo.max_file_size(), 1024 * 1024)}MB"}]})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: [%{message: "upload failed"}]})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{field: "photo", message: "is required"}]})
  end
end
