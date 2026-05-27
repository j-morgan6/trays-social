defmodule TraysSocial.DiagnosticsTest do
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Diagnostics
  alias TraysSocial.Diagnostics.IosDiagnosticPayload

  describe "store_payload/1" do
    test "inserts a diagnostic payload" do
      assert {:ok, %IosDiagnosticPayload{} = record} =
               Diagnostics.store_payload(%{
                 payload_type: "diagnostic",
                 payload: %{"crashDiagnostics" => []},
                 app_version: "1.0.0",
                 os_version: "17.5",
                 device_model: "iPhone15,3",
                 received_at: utc_now()
               })

      assert record.payload_type == "diagnostic"
      assert record.payload == %{"crashDiagnostics" => []}
      assert record.app_version == "1.0.0"
      assert record.user_id == nil
    end

    test "accepts an authenticated user_id" do
      user = user_fixture()

      assert {:ok, record} =
               Diagnostics.store_payload(%{
                 user_id: user.id,
                 payload_type: "metric",
                 payload: %{"metricPayload" => %{}},
                 received_at: utc_now()
               })

      assert record.user_id == user.id
    end

    test "rejects an unknown payload_type" do
      assert {:error, changeset} =
               Diagnostics.store_payload(%{
                 payload_type: "telemetry",
                 payload: %{},
                 received_at: utc_now()
               })

      assert errors_on(changeset).payload_type == ["is invalid"]
    end

    test "rejects a missing payload" do
      assert {:error, changeset} =
               Diagnostics.store_payload(%{
                 payload_type: "diagnostic",
                 received_at: utc_now()
               })

      assert errors_on(changeset).payload == ["can't be blank"]
    end

    test "stores an arbitrarily-shaped payload without inner validation" do
      # The pitfall: Apple changes the inner schema across iOS releases.
      # We must NOT reject a payload because its shape doesn't match a
      # specific iOS version.
      weird_payload = %{
        "futureField" => 42,
        "nested" => %{"deeper" => [1, 2, 3]},
        "string" => "hello"
      }

      assert {:ok, record} =
               Diagnostics.store_payload(%{
                 payload_type: "diagnostic",
                 payload: weird_payload,
                 received_at: utc_now()
               })

      assert record.payload == weird_payload
    end
  end

  describe "list_recent/1" do
    test "orders by received_at desc and respects :limit" do
      now = utc_now()

      {:ok, oldest} = insert_payload(received_at: shift(now, -3600))
      {:ok, middle} = insert_payload(received_at: shift(now, -1800))
      {:ok, newest} = insert_payload(received_at: now)

      records = Diagnostics.list_recent(limit: 50)
      ids = Enum.map(records, & &1.id)

      # newest first
      assert ids == [newest.id, middle.id, oldest.id]
    end

    test "respects :limit" do
      for offset <- 0..5 do
        insert_payload(received_at: shift(utc_now(), -offset))
      end

      records = Diagnostics.list_recent(limit: 3)
      assert length(records) == 3
    end

    test "filters by :payload_type" do
      insert_payload(payload_type: "diagnostic")
      insert_payload(payload_type: "metric")
      insert_payload(payload_type: "metric")

      assert length(Diagnostics.list_recent(payload_type: "diagnostic")) == 1
      assert length(Diagnostics.list_recent(payload_type: "metric")) == 2
    end

    test "filters by :user_id" do
      user = user_fixture()
      insert_payload(user_id: user.id)
      insert_payload()

      records = Diagnostics.list_recent(user_id: user.id)
      assert length(records) == 1
      assert hd(records).user_id == user.id
    end
  end

  describe "get_payload!/1" do
    test "returns the payload by id" do
      {:ok, record} = insert_payload()

      assert %IosDiagnosticPayload{id: id} = Diagnostics.get_payload!(record.id)
      assert id == record.id
    end

    test "raises when the id is not found" do
      assert_raise Ecto.NoResultsError, fn -> Diagnostics.get_payload!(-1) end
    end
  end

  defp insert_payload(overrides \\ []) do
    Diagnostics.store_payload(
      Enum.into(overrides, %{
        payload_type: "diagnostic",
        payload: %{"crashDiagnostics" => []},
        received_at: utc_now()
      })
    )
  end

  defp utc_now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp shift(%DateTime{} = dt, seconds), do: DateTime.add(dt, seconds, :second)
end
