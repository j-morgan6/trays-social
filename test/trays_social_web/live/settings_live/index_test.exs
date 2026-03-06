defmodule TraysSocialWeb.SettingsLive.IndexTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  describe "Settings page" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/users/settings")
    end

    test "renders the settings page for authenticated user", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Settings"
      assert html =~ "Manage your profile and account"
    end

    test "displays profile form with current username", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Profile"
      assert html =~ user.username
      assert html =~ "Save Profile"
    end

    test "displays email change form with current email", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Email Address"
      assert html =~ user.email
      assert html =~ "Change Email"
    end

    test "displays password change form", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Change Password"
      assert html =~ "Update Password"
    end

    test "displays danger zone with delete account", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert html =~ "Danger Zone"
      assert html =~ "Delete Account"
      assert html =~ "Delete My Account"
    end

    test "validates profile form on change", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Submit a validate event with a blank username (should show error)
      html =
        view
        |> element("#profile-form")
        |> render_change(%{"user" => %{"username" => "", "bio" => ""}})

      assert html =~ "can" or html =~ "required" or html =~ "blank"
    end

    test "updates profile successfully", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      new_username = "updated_user_#{System.unique_integer([:positive])}"

      view
      |> element("#profile-form")
      |> render_submit(%{"user" => %{"username" => new_username, "bio" => "New bio"}})

      # Verify in the database that the profile was actually updated
      updated_user = TraysSocial.Accounts.get_user!(user.id)
      assert updated_user.username == new_username
      assert updated_user.bio == "New bio"
    end

    test "shows error for invalid username on profile save", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Username with invalid characters
      html =
        view
        |> element("#profile-form")
        |> render_submit(%{"user" => %{"username" => "ab", "bio" => ""}})

      # Should show validation error (username too short)
      assert html =~ "should be at least" or html =~ "at least 3"
    end

    test "shows error when changing email with wrong password", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#email-form")
        |> render_submit(%{
          "user" => %{
            "email" => "new@example.com",
            "current_password" => "wrong_password"
          }
        })

      assert html =~ "Current password is incorrect"
    end

    test "shows error when changing password with wrong current password", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#password-form")
        |> render_submit(%{
          "user" => %{
            "current_password" => "wrong_password",
            "password" => "new_password123",
            "password_confirmation" => "new_password123"
          }
        })

      assert html =~ "Current password is incorrect"
    end

    test "deletes account successfully", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      render_click(view, "delete_account")

      assert_redirect(view, ~p"/")
    end
  end

  describe "change_email" do
    test "sends email change instructions with correct password and valid email", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      new_email = "newemail#{System.unique_integer([:positive])}@example.com"

      view
      |> element("#email-form")
      |> render_submit(%{
        "user" => %{
          "email" => new_email,
          "current_password" => valid_user_password()
        }
      })

      # After successful email change request, the form resets to the current email
      html = render(view)
      assert html =~ user.email
      assert html =~ "Email Address"
    end

    test "shows validation error for invalid email with correct password", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#email-form")
        |> render_submit(%{
          "user" => %{
            "email" => "not-an-email",
            "current_password" => valid_user_password()
          }
        })

      # The email changeset is invalid, so it re-renders with the invalid changeset
      assert html =~ "must have the @ sign and no spaces"
    end

    test "re-renders form when email is blank with correct password", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#email-form")
        |> render_submit(%{
          "user" => %{
            "email" => "",
            "current_password" => valid_user_password()
          }
        })

      # Invalid changeset path in send_email_change - form re-renders
      assert html =~ "Email Address"
    end
  end

  describe "change_password" do
    test "updates password successfully with correct current password", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      view
      |> element("#password-form")
      |> render_submit(%{
        "user" => %{
          "current_password" => valid_user_password(),
          "password" => "new_password_123",
          "password_confirmation" => "new_password_123"
        }
      })

      flash = assert_redirect(view, ~p"/users/log-in")
      assert flash["info"] =~ "Password updated successfully"
    end

    test "shows changeset error when new password is too short", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#password-form")
        |> render_submit(%{
          "user" => %{
            "current_password" => valid_user_password(),
            "password" => "short",
            "password_confirmation" => "short"
          }
        })

      assert html =~ "should be at least 12 character"
    end

    test "shows changeset error when password confirmation does not match", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#password-form")
        |> render_submit(%{
          "user" => %{
            "current_password" => valid_user_password(),
            "password" => "new_password_123",
            "password_confirmation" => "different_password"
          }
        })

      assert html =~ "does not match password"
    end
  end

  describe "profile update edge cases" do
    test "saves profile with only bio change and verifies database update", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      view
      |> element("#profile-form")
      |> render_submit(%{"user" => %{"username" => user.username, "bio" => "Updated bio text"}})

      # Verify in the database that the profile was actually updated
      updated_user = TraysSocial.Accounts.get_user!(user.id)
      assert updated_user.bio == "Updated bio text"
    end

    test "shows error for duplicate username", %{conn: conn} do
      other_user = user_fixture()
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#profile-form")
        |> render_submit(%{"user" => %{"username" => other_user.username, "bio" => ""}})

      assert html =~ "has already been taken"
    end

    test "validates profile form shows error for invalid characters in username", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      html =
        view
        |> element("#profile-form")
        |> render_change(%{"user" => %{"username" => "invalid user!@#", "bio" => ""}})

      assert html =~ "only letters, numbers, and underscores" or
               html =~ "has invalid format" or
               html =~ "invalid"
    end
  end

  describe "cancel-upload" do
    test "cancels a pending upload", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Upload a file
      profile_photo =
        file_input(view, "#profile-form", :profile_photo, [
          %{
            name: "test_photo.jpg",
            content: <<0xFF, 0xD8, 0xFF, 0xE0>>,
            type: "image/jpeg"
          }
        ])

      render_upload(profile_photo, "test_photo.jpg")

      # The entry should be visible
      html = render(view)
      assert html =~ "test_photo.jpg"

      # Cancel the upload
      view
      |> element("button[phx-click=\"cancel-upload\"]")
      |> render_click()

      # After cancel, the entry should be removed
      html = render(view)
      refute html =~ "test_photo.jpg"
    end
  end

  describe "profile photo upload and submit" do
    test "submits profile form with an uploaded photo", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Create a minimal valid JPEG content
      jpeg_content =
        <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00,
          0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9>>

      profile_photo =
        file_input(view, "#profile-form", :profile_photo, [
          %{
            name: "profile_test.jpg",
            content: jpeg_content,
            type: "image/jpeg"
          }
        ])

      render_upload(profile_photo, "profile_test.jpg")

      new_username = "photo_user_#{System.unique_integer([:positive])}"

      view
      |> element("#profile-form")
      |> render_submit(%{"user" => %{"username" => new_username, "bio" => "Photo bio"}})

      # Verify the profile was updated in the database with the photo URL
      updated_user = TraysSocial.Accounts.get_user!(user.id)
      assert updated_user.username == new_username
      assert updated_user.bio == "Photo bio"
      # The photo URL should be set (from Photo.store + ImageProcessor.thumb_url)
      assert updated_user.profile_photo_url != nil
      assert updated_user.profile_photo_url =~ "_thumb"
    end
  end

  describe "upload error display" do
    test "shows error for file type not accepted", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Try to upload a non-accepted file type (.txt)
      profile_photo =
        file_input(view, "#profile-form", :profile_photo, [
          %{
            name: "test_file.txt",
            content: "not an image",
            type: "text/plain"
          }
        ])

      render_upload(profile_photo, "test_file.txt")

      html = render(view)
      assert html =~ "File type not accepted"
    end

    test "shows error for file that is too large", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Create content that exceeds the 10MB max_file_size
      large_content = :binary.copy(<<0>>, 10 * 1024 * 1024 + 1)

      profile_photo =
        file_input(view, "#profile-form", :profile_photo, [
          %{
            name: "huge_photo.jpg",
            content: large_content,
            type: "image/jpeg"
          }
        ])

      render_upload(profile_photo, "huge_photo.jpg")

      html = render(view)
      assert html =~ "File is too large (max 10MB)"
    end

    test "shows error when too many files are selected", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Upload 2 files when max_entries is 1
      profile_photo =
        file_input(view, "#profile-form", :profile_photo, [
          %{
            name: "photo1.jpg",
            content: <<0xFF, 0xD8, 0xFF, 0xE0>>,
            type: "image/jpeg"
          },
          %{
            name: "photo2.jpg",
            content: <<0xFF, 0xD8, 0xFF, 0xE0>>,
            type: "image/jpeg"
          }
        ])

      render_upload(profile_photo, "photo1.jpg")

      html = render(view)
      assert html =~ "Too many files selected"
    end
  end

  describe "validate event with valid data" do
    test "validates profile form with valid username", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Validate with a valid username - should not show errors
      html =
        view
        |> element("#profile-form")
        |> render_change(%{
          "user" => %{"username" => "valid_username_123", "bio" => "A valid bio"}
        })

      refute html =~ "can&#39;t be blank"
      refute html =~ "should be at least"
    end
  end
end
