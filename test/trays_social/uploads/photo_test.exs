defmodule TraysSocial.Uploads.PhotoTest do
  use TraysSocial.DataCase

  alias TraysSocial.Uploads.Photo

  describe "validate_extension/1" do
    test "accepts jpg files" do
      assert :ok = Photo.validate_extension("photo.jpg")
      assert :ok = Photo.validate_extension("photo.JPG")
    end

    test "accepts jpeg files" do
      assert :ok = Photo.validate_extension("photo.jpeg")
      assert :ok = Photo.validate_extension("photo.JPEG")
    end

    test "accepts png files" do
      assert :ok = Photo.validate_extension("photo.png")
    end

    test "accepts heic files" do
      assert :ok = Photo.validate_extension("photo.heic")
      assert :ok = Photo.validate_extension("photo.HEIC")
    end

    test "rejects invalid extensions" do
      assert {:error, :invalid_extension} = Photo.validate_extension("photo.gif")
      assert {:error, :invalid_extension} = Photo.validate_extension("photo.exe")
      assert {:error, :invalid_extension} = Photo.validate_extension("photo.pdf")
    end
  end

  describe "generate_filename/1" do
    test "preserves file extension" do
      filename = Photo.generate_filename("photo.jpg")
      assert String.ends_with?(filename, ".jpg")
    end

    test "generates unique filenames" do
      filename1 = Photo.generate_filename("photo.jpg")
      filename2 = Photo.generate_filename("photo.jpg")
      assert filename1 != filename2
    end

    test "includes timestamp" do
      filename = Photo.generate_filename("photo.jpg")
      assert filename =~ ~r/^\d+_/
    end
  end

  describe "store/1" do
    setup do
      # D53: must lead with real JPEG magic bytes (FF D8 FF) so the
      # validate_magic_bytes gate doesn't reject the test fixture.
      test_file_path = Path.join(System.tmp_dir!(), "test_upload.jpg")
      File.write!(test_file_path, <<0xFF, 0xD8, 0xFF, 0xE0>> <> "rest of fake image data")

      upload = %Plug.Upload{
        path: test_file_path,
        filename: "test.jpg",
        content_type: "image/jpeg"
      }

      on_exit(fn ->
        File.rm(test_file_path)
      end)

      {:ok, upload: upload, test_file_path: test_file_path}
    end

    test "stores file and returns public URL", %{upload: upload} do
      assert {:ok, public_url} = Photo.store(upload)
      assert String.starts_with?(public_url, "/uploads/")
      assert String.ends_with?(public_url, ".jpg")

      # Clean up
      Photo.delete(public_url)
    end

    test "rejects files with invalid extensions" do
      bad_upload = %Plug.Upload{
        path: "/tmp/fake.exe",
        filename: "bad.exe",
        content_type: "application/exe"
      }

      assert {:error, :invalid_extension} = Photo.store(bad_upload)
    end

    test "rejects HTML masquerading as a .jpg (D53)" do
      # The exact attack the magic-byte gate exists to defeat. Filename
      # passes validate_extension, but the bytes are not a JPEG and must
      # never reach Mogrify/ImageMagick.
      path = Path.join(System.tmp_dir!(), "evil_upload.jpg")
      File.write!(path, "<html><script>alert(1)</script></html>")
      on_exit(fn -> File.rm(path) end)

      upload = %Plug.Upload{path: path, filename: "evil.jpg", content_type: "image/jpeg"}

      assert {:error, :unsupported_image} = Photo.store(upload)
    end

    test "rejects valid PNG bytes uploaded with a .jpg extension (D53)" do
      # Magic bytes and extension must agree — a PNG renamed .jpg is a
      # signal of confusion or evasion.
      path = Path.join(System.tmp_dir!(), "renamed.jpg")
      File.write!(path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <> "png body")
      on_exit(fn -> File.rm(path) end)

      upload = %Plug.Upload{path: path, filename: "x.jpg", content_type: "image/jpeg"}

      assert {:error, :magic_mismatch} = Photo.store(upload)
    end

    test "accepts a valid PNG header (D53)" do
      path = Path.join(System.tmp_dir!(), "good.png")
      File.write!(path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <> "png body")
      on_exit(fn -> File.rm(path) end)

      upload = %Plug.Upload{path: path, filename: "x.png", content_type: "image/png"}

      assert {:ok, public_url} = Photo.store(upload)
      Photo.delete(public_url)
    end

    test "accepts a valid HEIC header (D53)" do
      path = Path.join(System.tmp_dir!(), "good.heic")
      # ISO base media: bytes 0..3 = box size, 4..7 = "ftyp", 8..11 = brand.
      File.write!(path, <<0, 0, 0, 32>> <> "ftyp" <> "heic" <> "rest")
      on_exit(fn -> File.rm(path) end)

      upload = %Plug.Upload{path: path, filename: "x.heic", content_type: "image/heic"}

      assert {:ok, public_url} = Photo.store(upload)
      Photo.delete(public_url)
    end
  end

  describe "delete/1" do
    test "deletes existing file" do
      # Create a test file in uploads directory
      uploads_dir = "priv/static/uploads"
      File.mkdir_p!(uploads_dir)
      test_file = Path.join(uploads_dir, "test_delete.jpg")
      File.write!(test_file, "test data")

      assert :ok = Photo.delete("/uploads/test_delete.jpg")
      refute File.exists?(test_file)
    end

    test "returns ok for non-existent file" do
      assert :ok = Photo.delete("/uploads/non_existent.jpg")
    end

    test "handles nil input" do
      assert :ok = Photo.delete(nil)
    end
  end

  describe "max_file_size/0" do
    test "returns maximum file size in bytes" do
      assert is_integer(Photo.max_file_size())
      assert Photo.max_file_size() > 0
    end
  end

  describe "validate_size/1" do
    test "accepts files within size limit" do
      path = Path.join(System.tmp_dir!(), "small_file_#{System.unique_integer([:positive])}.jpg")
      File.write!(path, "small content")

      on_exit(fn -> File.rm(path) end)

      assert :ok = Photo.validate_size(path)
    end

    test "rejects files exceeding size limit" do
      path = Path.join(System.tmp_dir!(), "large_file_#{System.unique_integer([:positive])}.jpg")
      # Create a file larger than 10MB
      content = :binary.copy(<<0>>, 10 * 1024 * 1024 + 1)
      File.write!(path, content)

      on_exit(fn -> File.rm(path) end)

      assert {:error, :file_too_large} = Photo.validate_size(path)
    end

    test "returns error when file does not exist" do
      assert {:error, :enoent} = Photo.validate_size("/tmp/nonexistent_file_for_test.jpg")
    end
  end

  describe "delete/1 edge cases" do
    test "handles non-binary non-nil input gracefully" do
      assert :ok = Photo.delete(123)
      assert :ok = Photo.delete(:atom)
    end
  end

  describe "allowed_extensions/0" do
    test "returns list of allowed extensions" do
      extensions = Photo.allowed_extensions()
      assert is_list(extensions)
      assert ".jpg" in extensions
      assert ".png" in extensions
    end
  end
end
