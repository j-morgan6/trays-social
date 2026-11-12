defmodule TraysSocialWeb.PostLive.ShowTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  describe "Show" do
    test "displays post with all details", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      assert html =~ post.user.username
      assert html =~ post.caption
      # Editorial recipe page renders cook time via format_cook_time/1
      # which produces compact forms like "42 min" / "2 hr 45 min".
      assert html =~ "#{post.cooking_time_minutes} min"
      assert html =~ post.photo_url
    end

    test "shows delete button for post owner", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/posts/#{post.id}")

      # Owner delete affordance is now a quiet inline button next to the title.
      assert html =~ ~s|phx-click="delete"|
    end

    test "does not show delete button for non-owner", %{conn: conn} do
      owner = user_fixture()
      other_user = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, _view, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/posts/#{post.id}")

      refute html =~ ~s|phx-click="delete"|
    end

    test "deletes post when owner clicks delete button", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/posts/#{post.id}")

      assert view
             |> element(~s|button[phx-click="delete"]|)
             |> render_click()

      assert_redirect(view, ~p"/feed")

      # Verify post was soft deleted
      deleted_post = TraysSocial.Repo.get(TraysSocial.Posts.Post, post.id)
      assert deleted_post.deleted_at != nil
    end

    test "back to feed link works", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      assert view
             |> element("a", "Back to feed")
             |> render_click()

      assert_redirect(view, ~p"/feed")
    end

    test "authenticated user can toggle like on a post", %{conn: conn} do
      owner = user_fixture()
      liker = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, view, html} =
        conn
        |> log_in_user(liker)
        |> live(~p"/posts/#{post.id}")

      # Post starts with 0 likes
      assert html =~ "0"

      # Like the post
      html = render_click(view, "toggle-like")
      assert html =~ "1"

      # Unlike the post
      html = render_click(view, "toggle-like")
      assert html =~ "0"
    end

    test "unauthenticated user clicking like is redirected to login", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      render_click(view, "toggle-like")
      assert_redirect(view, ~p"/users/log-in")
    end

    test "authenticated user can add a comment", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, view, html} =
        conn
        |> log_in_user(commenter)
        |> live(~p"/posts/#{post.id}")

      # Comment form is visible for authenticated users. The editorial
      # design renames "comments" to "notes" — see show.html.heex.
      assert html =~ "Leave a note for the cook"

      # Submit a comment
      html =
        view
        |> form("form", comment: %{body: "Looks delicious!"})
        |> render_submit()

      assert html =~ "Looks delicious!"
      assert html =~ commenter.username
    end

    test "unauthenticated user sees login prompt instead of comment form", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      refute html =~ "Leave a note for the cook"
      assert html =~ "Log in"
      assert html =~ "to leave a note"
    end

    test "comment author can delete their own comment", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      post = post_fixture(user_id: owner.id)
      comment = comment_fixture(post, commenter, %{body: "Comment to delete"})

      {:ok, view, html} =
        conn
        |> log_in_user(commenter)
        |> live(~p"/posts/#{post.id}")

      assert html =~ "Comment to delete"

      # Delete the comment
      render_click(view, "delete-comment", %{"id" => to_string(comment.id)})

      html = render(view)
      refute html =~ "Comment to delete"
    end

    test "non-author cannot delete someone else's comment", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      other_user = user_fixture()
      post = post_fixture(user_id: owner.id)
      _comment = comment_fixture(post, commenter, %{body: "Not my comment"})

      {:ok, _view, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/posts/#{post.id}")

      # The comment is visible but the delete button should not be shown
      assert html =~ "Not my comment"
      # The Delete button is only rendered for the comment's own author
      refute html =~ "delete-comment"
    end

    test "update-comment-body event updates the comment body assign", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/posts/#{post.id}")

      # The event should update without error
      render_click(view, "update-comment-body", %{"value" => "typing..."})
      html = render(view)
      assert html =~ "typing..."
    end

    test "photo navigation with single photo is a no-op", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      # With a single photo, next/prev should be no-ops (no crash)
      render_click(view, "next-photo")
      render_click(view, "prev-photo")

      # Page still renders correctly
      html = render(view)
      assert html =~ post.caption
    end

    test "photo navigation with multiple photos cycles through them", %{conn: conn} do
      user = user_fixture()

      post =
        post_fixture(
          user_id: user.id,
          post_photos: [
            %{url: "/uploads/photo1.jpg", position: 0},
            %{url: "/uploads/photo2.jpg", position: 1},
            %{url: "/uploads/photo3.jpg", position: 2}
          ]
        )

      {:ok, view, html} = live(conn, ~p"/posts/#{post.id}")

      # Should start at photo 0, showing counter "1 / 3"
      assert html =~ "1 / 3"

      # Navigate forward
      html = render_click(view, "next-photo")
      assert html =~ "2 / 3"

      # Navigate forward again
      html = render_click(view, "next-photo")
      assert html =~ "3 / 3"

      # Wrap around to first
      html = render_click(view, "next-photo")
      assert html =~ "1 / 3"

      # Navigate backward (wraps to last)
      html = render_click(view, "prev-photo")
      assert html =~ "3 / 3"
    end

    test "non-owner cannot delete post", %{conn: conn} do
      owner = user_fixture()
      other_user = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/posts/#{post.id}")

      # Manually send the delete event (even though button is hidden)
      render_click(view, "delete")

      # User stays on the page (no redirect), post is still visible
      html = render(view)
      assert html =~ post.caption

      # Verify the post was NOT deleted
      db_post = TraysSocial.Repo.get(TraysSocial.Posts.Post, post.id)
      assert is_nil(db_post.deleted_at)
    end

    test "unauthenticated user trying to comment is redirected", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      render_click(view, "add-comment", %{"comment" => %{"body" => "test"}})
      assert_redirect(view, ~p"/users/log-in")
    end

    test "hides comments from users the viewer has blocked", %{conn: conn} do
      owner = user_fixture()
      viewer = user_fixture()
      blocked = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, _} = TraysSocial.Posts.create_comment(post, viewer, %{body: "From the viewer"})
      {:ok, _} = TraysSocial.Posts.create_comment(post, blocked, %{body: "From the blocked"})

      {:ok, _block} = TraysSocial.Accounts.block_user(viewer.id, blocked.id)

      {:ok, _view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/posts/#{post.id}")

      assert html =~ "From the viewer"
      refute html =~ "From the blocked"
    end

    test "displays comment count", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      post = post_fixture(user_id: owner.id)
      _comment = comment_fixture(post, commenter, %{body: "A comment"})

      # Reload post to get updated comment_count
      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      # Comment count is surfaced in the collapsed "cooks left notes"
      # summary and in the engagement row ("1 notes" / "N notes").
      assert html =~ "1 cook left a note"
      assert html =~ "A comment"
    end

    test "toggle-bookmark saves and unsaves the post", %{conn: conn} do
      author = user_fixture()
      viewer = user_fixture()
      post = post_fixture(user_id: author.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/posts/#{post.id}")

      refute TraysSocial.Posts.bookmarked?(viewer.id, post.id)

      render_click(view, "toggle-bookmark")
      assert TraysSocial.Posts.bookmarked?(viewer.id, post.id)

      html = render(view)
      assert html =~ "Saved to My Tray"

      render_click(view, "toggle-bookmark")
      refute TraysSocial.Posts.bookmarked?(viewer.id, post.id)

      html = render(view)
      assert html =~ "Save to My Tray"
    end

    test "toggle-follow follows and unfollows the recipe author", %{conn: conn} do
      author = user_fixture()
      viewer = user_fixture()
      post = post_fixture(user_id: author.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/posts/#{post.id}")

      refute TraysSocial.Accounts.following?(viewer.id, author.id)

      render_click(view, "toggle-follow")
      assert TraysSocial.Accounts.following?(viewer.id, author.id)

      html = render(view)
      assert html =~ ~r/phx-click="toggle-follow"[^>]*>\s*Following/

      render_click(view, "toggle-follow")
      refute TraysSocial.Accounts.following?(viewer.id, author.id)
    end

    test "Cook badge renders next to recipe author's own replies", %{conn: conn} do
      author = user_fixture()
      other = user_fixture()
      post = post_fixture(user_id: author.id)
      _own_comment = comment_fixture(post, author, %{body: "Cook reply"})
      _other_comment = comment_fixture(post, other, %{body: "Visitor reply"})

      {:ok, _view, html} =
        conn
        |> log_in_user(other)
        |> live(~p"/posts/#{post.id}")

      # Both comments render; the author's comment is paired with the
      # Mint Whisper "Cook" badge.
      assert html =~ "Cook reply"
      assert html =~ "Visitor reply"
      assert html =~ ~r/#{author.username}[^<]*<\/span>\s*<span[^>]*>\s*Cook\s*</
    end

    test "toggle-ingredient checks and unchecks an ingredient", %{conn: conn} do
      author = user_fixture()
      viewer = user_fixture()
      post = post_fixture(user_id: author.id)
      [ingredient | _] = post.ingredients

      {:ok, view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/posts/#{post.id}")

      # Initial state — no line-through on the ingredient row.
      refute html =~ ~r/line-through[^"]*"[^>]*>\s*#{ingredient.name}/

      html = render_click(view, "toggle-ingredient", %{"id" => to_string(ingredient.id)})
      # After toggling, the ingredient name is rendered inside a line-through span.
      assert html =~ ~r/line-through[^"]*"[^>]*>\s*#{ingredient.name}/

      html = render_click(view, "toggle-ingredient", %{"id" => to_string(ingredient.id)})
      refute html =~ ~r/line-through[^"]*"[^>]*>\s*#{ingredient.name}/
    end

    test "toggle-cook-mode starts and stops the stopwatch", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/posts/#{post.id}")

      # Initial state — primary "Start cooking" CTA, no floating timer.
      assert html =~ "Start cooking"
      refute html =~ "cook-timer-display"

      html = render_click(view, "toggle-cook-mode")
      # Stopwatch is mounted with a data-started-at attribute; CTA flips to "Stop cooking".
      assert html =~ "Stop cooking"
      assert html =~ "cook-timer-display"
      assert html =~ ~s|data-started-at=|

      html = render_click(view, "toggle-cook-mode")
      assert html =~ "Start cooking"
      refute html =~ "cook-timer-display"
    end
  end

  describe "recipe page (W248)" do
    test "recipe sections render", %{conn: conn} do
      cook = user_fixture()
      viewer = user_fixture()

      post =
        post_fixture(
          user_id: cook.id,
          caption: "Lemon pasta. Finish with extra zest.",
          servings: 2,
          post_tags: [%{tag: "Weeknight"}]
        )

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/posts/#{post.id}")

      assert has_element?(view, "#recipe-hero img[src='#{post.photo_url}']")
      assert has_element?(view, "#recipe-kicker", "weeknight")
      assert has_element?(view, "#recipe-head h1", "Lemon pasta")
      assert has_element?(view, "#recipe-byline", "@#{cook.username}")
      assert has_element?(view, "#recipe-byline button[phx-click='toggle-follow']", "Follow")
      assert has_element?(view, "#recipe-meta", "42 min")
      assert has_element?(view, "#recipe-meta", "Serves 2")
      assert has_element?(view, "#recipe-meta", "1 ingredient")
      assert has_element?(view, "#recipe-note", "From #{cook.username}")
      assert has_element?(view, "#recipe-note", "Finish with extra zest")

      assert has_element?(
               view,
               "#recipe-actions button[phx-click='toggle-cook-mode']",
               "Start cooking"
             )

      assert has_element?(
               view,
               "#recipe-actions button[phx-click='toggle-bookmark']",
               "Save to My Tray"
             )

      assert has_element?(
               view,
               "#recipe-ingredients button[phx-click='toggle-ingredient']",
               "Test ingredient"
             )

      assert has_element?(view, "#recipe-steps li", "Test step")
      assert has_element?(view, "#cooks-notes")

      refute has_element?(view, "#legacy-photo-label")
      refute has_element?(view, "#legacy-note")

      # Wiring: each restyled control still drives its existing event when
      # clicked through the markup, not just via render_click(view, event).
      view |> element("#recipe-byline button[phx-click='toggle-follow']") |> render_click()
      assert has_element?(view, "#recipe-byline button[phx-click='toggle-follow']", "Following")

      view |> element("#recipe-actions button[phx-click='toggle-like']") |> render_click()
      assert has_element?(view, "#recipe-actions button[phx-click='toggle-like']", "1 helpful")

      view |> element("#recipe-actions button[phx-click='toggle-bookmark']") |> render_click()

      assert has_element?(
               view,
               "#recipe-actions button[phx-click='toggle-bookmark']",
               "Saved to My Tray"
             )

      view
      |> element("#recipe-ingredients button[phx-click='toggle-ingredient']")
      |> render_click()

      assert has_element?(
               view,
               "#recipe-ingredients button[aria-pressed='true']",
               "Test ingredient"
             )

      view |> element("#recipe-actions button[phx-click='toggle-cook-mode']") |> render_click()
      assert has_element?(view, "#cook-timer-display")
      view |> element("#recipe-actions button[phx-click='toggle-cook-mode']") |> render_click()
      refute has_element?(view, "#cook-timer-display")

      view |> form("#cooks-notes form", comment: %{body: "Made it twice"}) |> render_submit()
      assert has_element?(view, "#comments", "Made it twice")
      view |> element("#comments button[phx-click='delete-comment']") |> render_click()
      refute has_element?(view, "#comments", "Made it twice")

      assert has_element?(view, "#recipe a[href='/feed']", "Back to feed")

      # The carousel buttons on a multi-photo recipe.
      gallery =
        post_fixture(
          user_id: cook.id,
          post_photos: [
            %{url: "/uploads/gallery-a.jpg", position: 0},
            %{url: "/uploads/gallery-b.jpg", position: 1}
          ]
        )

      {:ok, gallery_view, _html} =
        conn |> log_in_user(viewer) |> live(~p"/posts/#{gallery.id}")

      gallery_view |> element("#recipe-hero button[phx-click='next-photo']") |> render_click()
      assert has_element?(gallery_view, "#recipe-hero img[src='/uploads/gallery-b.jpg']")
      assert has_element?(gallery_view, "#recipe-hero", "2 / 2")
      gallery_view |> element("#recipe-hero button[phx-click='prev-photo']") |> render_click()
      assert has_element?(gallery_view, "#recipe-hero img[src='/uploads/gallery-a.jpg']")
    end

    test "narrow-width and long-text guards hold", %{conn: conn} do
      username = String.pad_trailing("cook_#{System.unique_integer([:positive])}", 30, "x")
      cook = user_fixture(username: username)
      long_title = String.duplicate("Supercalifragilisticexpialidocious", 4)
      post = post_fixture(user_id: cook.id, caption: long_title <> ". A long note.")

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      # One column below lg; every grid child can shrink (D116, no sideways
      # scroll at 390 px). Actual layout is checked by hand at 1440/768/390.
      assert has_element?(view, "article#recipe.grid.grid-cols-1")
      refute has_element?(view, "#recipe > :not(.min-w-0)")

      # A long unbroken title wraps and a 30-character username truncates.
      assert has_element?(view, "#recipe-head h1.break-words", long_title)
      assert has_element?(view, "#recipe-byline a.truncate", cook.username)
      assert has_element?(view, "#recipe-byline span.truncate", "@#{cook.username}")
    end

    test "legacy photo post renders the Photo label", %{conn: conn} do
      cook = user_fixture()

      post =
        post_fixture(
          user_id: cook.id,
          type: "post",
          caption: "Sunday market haul. Peaches everywhere."
        )

      {:ok, view, html} = live(conn, ~p"/posts/#{post.id}")

      assert html =~ post.photo_url
      assert has_element?(view, "#legacy-photo-label", "Photo")
      assert has_element?(view, "#legacy-caption", "Sunday market haul. Peaches everywhere.")
      assert has_element?(view, "#legacy-note", "A photo post from before Trays had recipes")
      assert has_element?(view, "#recipe-byline", cook.username)
      assert has_element?(view, "#recipe-actions button[phx-click='toggle-bookmark']")

      refute has_element?(view, "#recipe-meta")
      refute has_element?(view, "#recipe-note")
      refute has_element?(view, "#recipe-ingredients")
      refute has_element?(view, "#recipe-steps")
      refute has_element?(view, "button[phx-click='toggle-cook-mode']")
    end
  end

  describe "recipe opens" do
    alias TraysSocial.Posts.RecipeOpen
    alias TraysSocial.Repo

    test "a logged-in viewer's visit records a recipe open", %{conn: conn} do
      viewer = user_fixture()
      post = post_fixture(user_id: user_fixture().id)

      {:ok, _view, _html} = conn |> log_in_user(viewer) |> live(~p"/posts/#{post.id}")

      assert Repo.get_by(RecipeOpen, user_id: viewer.id, post_id: post.id)
    end

    test "a logged-out visit records nothing", %{conn: conn} do
      post = post_fixture(user_id: user_fixture().id)

      {:ok, _view, _html} = live(conn, ~p"/posts/#{post.id}")

      assert Repo.aggregate(RecipeOpen, :count) == 0
    end

    test "a visit across a block records nothing", %{conn: conn} do
      viewer = user_fixture()
      author = user_fixture()
      post = post_fixture(user_id: author.id)
      {:ok, _} = TraysSocial.Accounts.block_user(author.id, viewer.id)

      {:ok, _view, _html} = conn |> log_in_user(viewer) |> live(~p"/posts/#{post.id}")

      refute Repo.get_by(RecipeOpen, user_id: viewer.id, post_id: post.id)
    end

    test "the disconnected (dead) render does not record", %{conn: conn} do
      viewer = user_fixture()
      post = post_fixture(user_id: user_fixture().id)

      conn = conn |> log_in_user(viewer) |> get(~p"/posts/#{post.id}")

      assert html_response(conn, 200)
      refute Repo.get_by(RecipeOpen, user_id: viewer.id, post_id: post.id)
    end
  end

  describe "likes and saves across a block (D121)" do
    setup %{conn: conn} do
      author = user_fixture()
      viewer = user_fixture()
      post = post_fixture(user_id: author.id)
      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/posts/#{post.id}")
      {:ok, _} = TraysSocial.Accounts.block_user(author.id, viewer.id)
      %{view: view, viewer: viewer, post: post}
    end

    test "toggle-like across a block leaves liked false and the count unchanged", %{
      view: view,
      viewer: viewer,
      post: post
    } do
      render_click(view, "toggle-like")

      assigns = :sys.get_state(view.pid).socket.assigns
      refute assigns.liked
      assert assigns.post.like_count == 0
      refute TraysSocial.Posts.liked_by?(post.id, viewer.id)
      assert TraysSocial.Posts.get_post!(post.id).like_count == 0
    end

    test "toggle-bookmark across a block saves nothing", %{view: view, viewer: viewer, post: post} do
      render_click(view, "toggle-bookmark")

      refute :sys.get_state(view.pid).socket.assigns.bookmarked
      refute TraysSocial.Posts.bookmarked?(viewer.id, post.id)
    end
  end

  describe "a recipe saved before a block (D121)" do
    test "does not show as saved or liked once the block exists", %{conn: conn} do
      author = user_fixture()
      viewer = user_fixture()
      post = post_fixture(user_id: author.id)
      {:ok, _} = TraysSocial.Posts.create_bookmark(viewer.id, post.id)
      {:ok, _} = TraysSocial.Posts.like_post(post, viewer)
      {:ok, _} = TraysSocial.Accounts.block_user(author.id, viewer.id)

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/posts/#{post.id}")

      assigns = :sys.get_state(view.pid).socket.assigns
      refute assigns.bookmarked
      refute assigns.liked
    end
  end
end
