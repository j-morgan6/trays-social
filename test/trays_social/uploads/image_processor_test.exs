defmodule TraysSocial.Uploads.ImageProcessorTest do
  use TraysSocial.DataCase, async: true

  alias TraysSocial.Uploads.ImageProcessor

  describe "thumb_url/1" do
    test "returns nil for nil input" do
      assert nil == ImageProcessor.thumb_url(nil)
    end

    test "appends _thumb before extension" do
      assert "/uploads/photo_thumb.jpg" == ImageProcessor.thumb_url("/uploads/photo.jpg")
    end

    test "works with png files" do
      assert "/uploads/image_thumb.png" == ImageProcessor.thumb_url("/uploads/image.png")
    end

    test "handles filenames with underscores" do
      assert "/uploads/my_photo_123_thumb.jpg" ==
               ImageProcessor.thumb_url("/uploads/my_photo_123.jpg")
    end

    test "handles URLs without extensions" do
      assert "/uploads/photo_thumb" == ImageProcessor.thumb_url("/uploads/photo")
    end
  end

  describe "medium_url/1" do
    test "returns nil for nil input" do
      assert nil == ImageProcessor.medium_url(nil)
    end

    test "appends _medium before extension" do
      assert "/uploads/photo_medium.jpg" == ImageProcessor.medium_url("/uploads/photo.jpg")
    end

    test "works with png files" do
      assert "/uploads/image_medium.png" == ImageProcessor.medium_url("/uploads/image.png")
    end

    test "handles filenames with underscores" do
      assert "/uploads/my_photo_123_medium.jpg" ==
               ImageProcessor.medium_url("/uploads/my_photo_123.jpg")
    end

    test "handles URLs without extensions" do
      assert "/uploads/photo_medium" == ImageProcessor.medium_url("/uploads/photo")
    end
  end

  describe "large_url/1" do
    test "returns nil for nil input" do
      assert nil == ImageProcessor.large_url(nil)
    end

    test "appends _large before extension" do
      assert "/uploads/photo_large.jpg" == ImageProcessor.large_url("/uploads/photo.jpg")
    end

    test "works with png files" do
      assert "/uploads/image_large.png" == ImageProcessor.large_url("/uploads/image.png")
    end

    test "handles filenames with underscores" do
      assert "/uploads/my_photo_123_large.jpg" ==
               ImageProcessor.large_url("/uploads/my_photo_123.jpg")
    end

    test "handles URLs without extensions" do
      # large_url returns the URL unchanged when no extension
      assert "/uploads/photo" == ImageProcessor.large_url("/uploads/photo")
    end
  end

  describe "process/1" do
    test "returns error when source file does not exist" do
      assert {:error, _reason} = ImageProcessor.process("/uploads/nonexistent_file.jpg")
    end

    test "returns error for invalid path" do
      assert {:error, _reason} = ImageProcessor.process("/no/such/path/image.jpg")
    end
  end
end
