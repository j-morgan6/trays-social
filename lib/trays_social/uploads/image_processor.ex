defmodule TraysSocial.Uploads.ImageProcessor do
  @moduledoc """
  Processes uploaded images into multiple size variants using Mogrify.

  Generates 3 variants with convention-based naming:
  - _thumb: 300x300px square crop (for feed cards)
  - _medium: 800px wide, aspect ratio preserved (feed detail)
  - _large: 1200px wide, aspect ratio preserved (post detail)
  """

  @upload_directory "priv/static"

  @doc """
  Generates 3 size variants for an uploaded image.

  Given a public URL like "/uploads/abc123.jpg", creates:
  - /uploads/abc123_thumb.jpg
  - /uploads/abc123_medium.jpg
  - /uploads/abc123_large.jpg

  Returns {:ok, public_url} or {:error, reason}.
  """
  def process(public_url) when is_binary(public_url) do
    original_path = Path.join(@upload_directory, String.trim_leading(public_url, "/"))

    with :ok <- generate_thumb(original_path),
         :ok <- generate_medium(original_path),
         :ok <- generate_large(original_path) do
      {:ok, public_url}
    end
  end

  @doc """
  Returns the thumb variant URL (300x300 square crop).
  """
  def thumb_url(nil), do: nil

  def thumb_url(url) do
    ext = Path.extname(url)
    String.replace_trailing(url, ext, "") <> "_thumb" <> ext
  end

  @doc """
  Returns the medium variant URL (800px wide, aspect ratio preserved).
  """
  def medium_url(nil), do: nil

  def medium_url(url) do
    ext = Path.extname(url)
    String.replace_trailing(url, ext, "") <> "_medium" <> ext
  end

  @doc """
  Returns the large variant URL (1200px wide, aspect ratio preserved).
  """
  def large_url(nil), do: nil

  def large_url(url) do
    ext = Path.extname(url)
    if ext == "" do
      url
    else
      String.replace_trailing(url, ext, "") <> "_large" <> ext
    end
  end

  # 300x300 square crop for feed cards
  defp generate_thumb(original_path) do
    dest = variant_path(original_path, "_thumb")

    try do
      File.cp!(original_path, dest)

      Mogrify.open(dest)
      |> Mogrify.resize_to_fill("300x300")
      |> Mogrify.save(in_place: true)

      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # 800px wide, aspect ratio preserved
  defp generate_medium(original_path) do
    dest = variant_path(original_path, "_medium")

    try do
      File.cp!(original_path, dest)

      Mogrify.open(dest)
      |> Mogrify.resize("800x")
      |> Mogrify.save(in_place: true)

      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # 1200px wide, aspect ratio preserved
  defp generate_large(original_path) do
    dest = variant_path(original_path, "_large")

    try do
      File.cp!(original_path, dest)

      Mogrify.open(dest)
      |> Mogrify.resize("1200x")
      |> Mogrify.save(in_place: true)

      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp variant_path(original_path, suffix) do
    ext = Path.extname(original_path)
    String.replace_trailing(original_path, ext, "") <> suffix <> ext
  end
end
