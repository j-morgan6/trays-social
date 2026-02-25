defmodule TraysSocial.Uploads.Photo do
  @moduledoc """
  Handles photo uploads for posts.

  In development, stores files locally in priv/static/uploads.
  In production, can be configured to use S3 or similar cloud storage.
  """

  @upload_directory "priv/static/uploads"
  @max_file_size 10 * 1024 * 1024  # 10MB
  @allowed_extensions ~w(.jpg .jpeg .png .heic)

  @doc """
  Stores an uploaded file and returns the public URL.

  ## Examples

      iex> store(%Plug.Upload{filename: "photo.jpg", path: "/tmp/..."})
      {:ok, "/uploads/abc123.jpg"}

      iex> store(%Plug.Upload{filename: "bad.exe"})
      {:error, :invalid_extension}

  """
  def store(%Plug.Upload{} = upload) do
    with :ok <- validate_extension(upload.filename),
         :ok <- validate_size(upload.path) do
      destination = generate_filename(upload.filename)
      full_path = Path.join(@upload_directory, destination)

      case File.cp(upload.path, full_path) do
        :ok ->
          public_url = "/uploads/#{destination}"
          # Generate size variants — best effort, don't fail upload if processing fails
          TraysSocial.Uploads.ImageProcessor.process(public_url)
          {:ok, public_url}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Validates file extension against allowed types.
  """
  def validate_extension(filename) do
    extension = Path.extname(filename) |> String.downcase()

    if extension in @allowed_extensions do
      :ok
    else
      {:error, :invalid_extension}
    end
  end

  @doc """
  Validates file size is within limits.
  """
  def validate_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_file_size ->
        :ok

      {:ok, %{size: _}} ->
        {:error, :file_too_large}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a unique filename with timestamp and random string.
  """
  def generate_filename(original_filename) do
    extension = Path.extname(original_filename)
    timestamp = System.system_time(:second)
    random_string = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    "#{timestamp}_#{random_string}#{extension}"
  end

  @doc """
  Deletes a photo file from storage.

  ## Examples

      iex> delete("/uploads/photo.jpg")
      :ok

  """
  def delete(public_url) when is_binary(public_url) do
    filename = Path.basename(public_url)
    full_path = Path.join(@upload_directory, filename)

    case File.rm(full_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok  # Already deleted
      {:error, reason} -> {:error, reason}
    end
  end

  def delete(_), do: :ok

  @doc """
  Returns the maximum allowed file size in bytes.
  """
  def max_file_size, do: @max_file_size

  @doc """
  Returns the list of allowed file extensions.
  """
  def allowed_extensions, do: @allowed_extensions
end
