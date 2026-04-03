defmodule TraysSocialWeb.API.V1.UploadControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  setup :register_and_api_authenticate_user

  @upload_dir "priv/static/uploads"

  setup do
    File.mkdir_p!(@upload_dir)
    on_exit(fn -> File.rm_rf!(@upload_dir) end)
    :ok
  end

  describe "POST /api/v1/uploads" do
    test "uploads a valid photo and returns URL", %{conn: conn} do
      upload = %Plug.Upload{
        path: create_test_image(),
        filename: "test.jpg",
        content_type: "image/jpeg"
      }

      conn = post(conn, ~p"/api/v1/uploads", %{photo: upload})

      assert %{"data" => %{"url" => url}} = json_response(conn, 201)
      assert String.starts_with?(url, "/uploads/")
      assert String.ends_with?(url, ".jpg")
    end

    test "rejects invalid file extension", %{conn: conn} do
      upload = %Plug.Upload{
        path: create_test_file("test.txt"),
        filename: "test.txt",
        content_type: "text/plain"
      }

      conn = post(conn, ~p"/api/v1/uploads", %{photo: upload})

      assert %{"errors" => [%{"field" => "photo", "message" => msg}]} = json_response(conn, 422)
      assert msg =~ "invalid file type"
    end

    test "rejects request without photo", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/uploads", %{})

      assert %{"errors" => [%{"field" => "photo", "message" => "is required"}]} =
               json_response(conn, 422)
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/uploads", %{})

      assert json_response(conn, 401)
    end
  end

  defp create_test_image do
    path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.jpg")
    # Create a minimal valid file (just needs to exist and be under size limit)
    File.write!(path, :crypto.strong_rand_bytes(100))
    path
  end

  defp create_test_file(filename) do
    path = Path.join(System.tmp_dir!(), filename)
    File.write!(path, "test content")
    path
  end
end
