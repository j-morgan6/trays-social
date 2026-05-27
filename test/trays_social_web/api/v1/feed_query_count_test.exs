defmodule TraysSocialWeb.API.V1.FeedQueryCountTest do
  @moduledoc """
  W132: regression test that GET /api/v1/feed stays at single-digit
  query count regardless of how many posts + authors come back.

  Without preloads, this endpoint would do 1 query for the post list
  + 1 query per association per post (1 + N × 6 = 61 queries for a
  10-post page). With the array-form preloads in `Posts.list_posts/1`
  Ecto batches each association into a single IN-clause query, so a
  10-post page should be: posts + 6 preloads + 1 personalization
  short-circuit + 1 liked-ids + 1 bookmarked-ids = 10 queries.

  This test attaches a telemetry handler to the repo query event,
  captures the count for the request lifetime, and asserts the upper
  bound. The bound is intentionally loose (≤15) — it's the regression
  signal, not the perf bar. If a future change adds preloads or
  context calls, this test surfaces the growth instead of letting it
  silently drift. A genuine N+1 on a 10-post page would be ~60+
  queries, so even the loose bound catches the real failure mode.
  """

  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  test "GET /api/v1/feed with 10 posts executes a single-digit query count", %{conn: conn} do
    other_users =
      for _ <- 1..10 do
        user_fixture()
      end

    for u <- other_users do
      post_fixture(%{user_id: u.id})
    end

    {count, _} = with_query_counter(fn -> get(conn, ~p"/api/v1/feed") end)

    assert count <= 15,
           "feed executed #{count} queries — N+1 budget exceeded; an N+1 on a 10-post page would be ~60 queries"
  end

  defp with_query_counter(fun) do
    counter = :counters.new(1, [:atomics])
    ref = make_ref()
    handler_id = "feed-query-counter-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:trays_social, :repo, :query],
      fn _event, _measurements, _metadata, %{counter: c, ref: ^ref} ->
        :counters.add(c, 1, 1)
      end,
      %{counter: counter, ref: ref}
    )

    result =
      try do
        fun.()
      after
        :telemetry.detach(handler_id)
      end

    {:counters.get(counter, 1), result}
  end
end
