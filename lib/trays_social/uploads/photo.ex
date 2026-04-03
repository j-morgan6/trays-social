defmodule TraysSocial.Uploads.Photo do
  @moduledoc """
  Handles photo uploads for posts.

  Storage backend is configured via `:trays_social, :storage_backend`:
  - `:local` — stores files in priv/static/uploads (default, used in dev/test)
  - `:s3` — stores files in S3 (used in production)
  """

  # 10MB
  @max_file_size 10 * 1024 * 1024
  @allowed_extensions ~w(.jpg .jpeg .png .heic)

  @doc """
  Returns the configured storage backend (:local or :s3).
  """
  def storage_backend do
    Application.get_env(:trays_social, :storage_backend, :local)
  end

  @doc """
  Returns the configured upload directory (for local storage).
  """
  def upload_dir do
    Application.get_env(:trays_social, :upload_dir, "priv/static/uploads")
  end

  @doc """
  Returns the S3 bucket name.
  """
  def s3_bucket do
    Application.get_env(:trays_social, :s3_bucket)
  end

  @doc """
  Returns the base URL for S3 objects.
  """
  def s3_base_url do
    Application.get_env(:trays_social, :s3_base_url)
  end

  @doc """
  Stores an uploaded file and returns the public URL.

  Dispatches to local or S3 storage based on configuration.
  """
  def store(%Plug.Upload{} = upload) do
    with :ok <- validate_extension(upload.filename),
         :ok <- validate_size(upload.path) do
      case storage_backend() do
        :s3 -> store_s3(upload)
        _ -> store_local(upload)
      end
    end
  end

  defp store_local(upload) do
    dir = upload_dir()
    File.mkdir_p!(dir)
    destination = generate_filename(upload.filename)
    full_path = Path.join(dir, destination)

    case File.cp(upload.path, full_path) do
      :ok ->
        public_url = "/uploads/#{destination}"
        TraysSocial.Uploads.ImageProcessor.process(public_url)
        {:ok, public_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_s3(upload) do
    destination = generate_filename(upload.filename)
    bucket = s3_bucket()

    case File.read(upload.path) do
      {:ok, content} ->
        content_type = MIME.from_path(upload.filename)

        request =
          ExAws.S3.put_object(bucket, destination, content,
            content_type: content_type,
            acl: :public_read
          )

        case ExAws.request(request) do
          {:ok, _} ->
            public_url = "#{s3_base_url()}/#{destination}"
            store_s3_variants(upload.path, destination, bucket)
            {:ok, public_url}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_s3_variants(local_path, destination, bucket) do
    base = Path.rootname(destination)
    ext = Path.extname(destination)

    variants = [
      {"_thumb", "300x300"},
      {"_medium", "800x"},
      {"_large", "1200x"}
    ]

    for {suffix, size} <- variants do
      variant_name = "#{base}#{suffix}#{ext}"
      variant_local = Path.join(System.tmp_dir!(), variant_name)

      try do
        File.cp!(local_path, variant_local)

        if String.contains?(size, "x") and not String.ends_with?(size, "x") do
            Mogrify.open(variant_local) |> Mogrify.resize_to_fill(size) |> Mogrify.save(in_place: true)
          else
            Mogrify.open(variant_local) |> Mogrify.resize(size) |> Mogrify.save(in_place: true)
          end

        if File.exists?(variant_local) do
          content = File.read!(variant_local)
          content_type = MIME.from_path(variant_name)

          ExAws.S3.put_object(bucket, variant_name, content,
            content_type: content_type,
            acl: :public_read
          )
          |> ExAws.request()
        end
      rescue
        _ -> :ok
      after
        File.rm(variant_local)
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
  """
  def delete(public_url) when is_binary(public_url) do
    case storage_backend() do
      :s3 -> delete_s3(public_url)
      _ -> delete_local(public_url)
    end
  end

  def delete(_), do: :ok

  defp delete_local(public_url) do
    filename = Path.basename(public_url)
    full_path = Path.join(upload_dir(), filename)

    case File.rm(full_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_s3(public_url) do
    filename = Path.basename(public_url)
    bucket = s3_bucket()

    case ExAws.S3.delete_object(bucket, filename) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the maximum allowed file size in bytes.
  """
  def max_file_size, do: @max_file_size

  @doc """
  Returns the list of allowed file extensions.
  """
  def allowed_extensions, do: @allowed_extensions
end
