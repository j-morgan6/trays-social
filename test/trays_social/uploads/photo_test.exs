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
      # Create a test file
      test_file_path = Path.join(System.tmp_dir!(), "test_upload.jpg")
      File.write!(test_file_path, "fake image data")

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

  describe "allowed_extensions/0" do
    test "returns list of allowed extensions" do
      extensions = Photo.allowed_extensions()
      assert is_list(extensions)
      assert ".jpg" in extensions
      assert ".png" in extensions
    end
  end
end
