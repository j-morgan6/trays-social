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
    # D53: validate_magic_bytes BEFORE the file reaches Mogrify/ImageMagick.
    # ImageMagick has the worst CVE history of any image library in common
    # use (delegate-path command injection, parser vulns); the cheapest
    # mitigation is to refuse anything whose first bytes don't match the
    # declared extension. validate_extension alone trusts client filename
    # and would happily pass an .html-payload-renamed-to-.jpg to Mogrify.
    with :ok <- validate_extension(upload.filename),
         :ok <- validate_size(upload.path),
         {:ok, sniffed_type} <- validate_magic_bytes(upload.path, upload.filename) do
      content_type = sniffed_to_mime(sniffed_type)

      case storage_backend() do
        :s3 -> store_s3(upload, content_type)
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

  defp store_s3(upload, content_type) do
    destination = generate_filename(upload.filename)
    bucket = s3_bucket()

    case File.read(upload.path) do
      {:ok, content} ->
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
  Validates that the file's first bytes match the declared extension (D53).

  ImageMagick has a long CVE history (delegate-path command injection in
  particular); refusing files whose magic bytes don't match the declared
  extension closes the gap between asserted and actual content before
  Mogrify ever runs.

  Returns `{:ok, sniffed_type}` where sniffed_type is one of `:jpeg`,
  `:png`, `:heic`, or `{:error, :unsupported_image | :magic_mismatch | ...}`
  on rejection.
  """
  def validate_magic_bytes(path, filename) do
    extension = Path.extname(filename) |> String.downcase()

    with {:ok, header} <- read_header(path),
         {:ok, sniffed} <- sniff_image_type(header),
         :ok <- match_extension(sniffed, extension) do
      {:ok, sniffed}
    end
  end

  # Read enough bytes to identify any of our accepted types. HEIC needs the
  # ftyp box at offset 4 with a brand at offset 8 — 16 bytes covers all
  # three formats.
  defp read_header(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        result = IO.binread(file, 16)
        File.close(file)

        case result do
          data when is_binary(data) and byte_size(data) >= 8 -> {:ok, data}
          _ -> {:error, :unreadable}
        end

      {:error, _} ->
        {:error, :unreadable}
    end
  end

  defp sniff_image_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, :jpeg}

  defp sniff_image_type(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>),
    do: {:ok, :png}

  # ISO base media file format: bytes 4..7 = "ftyp", bytes 8..11 = the
  # major brand. Accept the HEIC brands Apple emits.
  defp sniff_image_type(<<_::32, "ftyp", brand::binary-size(4), _::binary>>) do
    case brand do
      "heic" -> {:ok, :heic}
      "heix" -> {:ok, :heic}
      "hevc" -> {:ok, :heic}
      "mif1" -> {:ok, :heic}
      "msf1" -> {:ok, :heic}
      _ -> {:error, :unsupported_image}
    end
  end

  defp sniff_image_type(_), do: {:error, :unsupported_image}

  defp match_extension(:jpeg, ext) when ext in [".jpg", ".jpeg"], do: :ok
  defp match_extension(:png, ".png"), do: :ok
  defp match_extension(:heic, ".heic"), do: :ok
  defp match_extension(_, _), do: {:error, :magic_mismatch}

  defp sniffed_to_mime(:jpeg), do: "image/jpeg"
  defp sniffed_to_mime(:png), do: "image/png"
  defp sniffed_to_mime(:heic), do: "image/heic"

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
