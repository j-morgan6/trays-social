defmodule TraysSocialWeb.API.V1.ReportControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "POST /api/v1/reports — ad reports (G38/W158)" do
    # Ads are ephemeral slots, not stored records: target_id carries the slot
    # index and the client self-describes the surface in details.
    test "accepts an ad report with slot index as target_id", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/reports", %{
          target_type: "ad",
          target_id: 0,
          reason: "inappropriate",
          details: "placement=feed slot=0"
        })

      assert %{"data" => %{"message" => "Report submitted successfully"}} =
               json_response(conn, 200)
    end

    test "rejects a duplicate open ad report for the same slot by the same user",
         %{conn: conn} do
      params = %{
        target_type: "ad",
        target_id: 0,
        reason: "inappropriate",
        details: "placement=feed slot=0"
      }

      first = post(conn, ~p"/api/v1/reports", params)
      assert json_response(first, 200)

      duplicate = post(conn, ~p"/api/v1/reports", params)
      assert %{"errors" => errors} = json_response(duplicate, 422)
      assert errors != %{}
    end

    test "rejects unknown target types", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/reports", %{
          target_type: "banner",
          target_id: 0,
          reason: "inappropriate"
        })

      assert %{"errors" => %{"target_type" => ["is invalid"]}} = json_response(conn, 422)
    end
  end

  describe "POST /api/v1/reports — baseline" do
    test "accepts a post report", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})

      conn =
        post(conn, ~p"/api/v1/reports", %{
          target_type: "post",
          target_id: post_record.id,
          reason: "spam",
          details: "looks like spam"
        })

      assert %{"data" => %{"message" => "Report submitted successfully"}} =
               json_response(conn, 200)
    end
  end
end
