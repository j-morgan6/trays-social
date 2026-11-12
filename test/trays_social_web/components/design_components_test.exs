defmodule TraysSocialWeb.DesignComponentsTest do
  # W240: the shared redesign components render the canvas token classes,
  # their copy and their accessibility labels.
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import TraysSocialWeb.DesignComponents

  defp assert_classes(html, classes) do
    for class <- classes, do: assert(html =~ class, "expected #{inspect(class)} in the markup")
  end

  describe "recipe_card/1" do
    test "renders the card, photo, time pill, badge and byline" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.recipe_card
          navigate="/posts/7"
          title="Harissa chickpea stew"
          photo_url="/uploads/a.jpg"
          aspect="4:5"
          cook_time="25 min"
          badge={:new}
          author_name="noor"
          context="Yesterday"
        />
        """)

      assert html =~ ~s(href="/posts/7")
      assert html =~ "/uploads/a_medium.jpg"
      assert_classes(html, ["rounded-[21px]", "shadow-card", "aspect-[4/5]", "bg-pill"])
      assert html =~ "25 min"
      assert html =~ "New"
      assert html =~ "Harissa chickpea stew"
      assert html =~ "noor"
      assert html =~ "Yesterday"
    end

    test "a rank badge reads #n" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.recipe_card navigate="/posts/1" title="Peanut noodles" author_name="sam" badge={{:rank, 2}} />
        """)

      assert html =~ "#2"
    end

    test "a legacy photo post gets the Photo tag and no time pill" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.recipe_card
          navigate="/posts/2"
          title="Saturday market haul"
          author_name="ren"
          kind={:photo_post}
          cook_time="10 min"
        />
        """)

      assert html =~ "Photo"
      refute html =~ "10 min"
      refute html =~ "bg-pill"
    end

    test "without an author the byline keeps the avatar's height" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.recipe_card navigate="/posts/4" title="Peanut noodles" context="2 days ago" />
        """)

      assert html =~ "2 days ago"
      assert html =~ "min-h-[22px]"
      refute html =~ "avatar"
      refute html =~ "·"
    end

    test "a missing photo renders the cream placeholder and no image" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.recipe_card navigate="/posts/3" title="Miso butter salmon" author_name="ren" />
        """)

      assert html =~ "bg-cream-lift"
      refute html =~ "<img"
    end
  end

  # W246: the My Tray list switch.
  describe "segmented_pills/1" do
    test "renders patch links, marks the selected pill and shows known counts" do
      assigns = %{
        options: [
          %{label: "My recipes", count: 7, patch: "/my-tray", selected: true},
          %{label: "Saved", count: nil, patch: "/my-tray?list=saved", selected: false}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.segmented_pills id="switch" label="My Tray lists" options={@options} />
        """)

      assert html =~ ~s(aria-label="My Tray lists")
      assert html =~ ~s(data-phx-link="patch")
      assert html =~ ~s(href="/my-tray?list=saved")
      assert html =~ ~r/aria-current="page"[^>]*>\s*<span class="truncate">My recipes/
      refute html =~ ~r/aria-current="page"[^>]*>\s*<span class="truncate">Saved/
      assert html =~ "bg-base-100 text-base-content shadow-card"
      assert html =~ ~s(<span class="opacity-75">7</span>)
      assert html |> String.split("opacity-75") |> length() == 2
      assert_classes(html, ["bg-base-300", "rounded-full", "min-h-11", "flex-1"])
    end
  end

  describe "row_card/1" do
    test "a ready match renders the mint Ready to cook pill" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_card
          navigate="/posts/4"
          title="Garlic chicken and crispy rice"
          photo_url="/uploads/b.jpg"
          author_name="lucia"
          detail="35 min"
          match={:ready}
          uses="Uses chicken, rice"
        />
        """)

      assert html =~ "Ready to cook"

      assert_classes(html, [
        "bg-mint-tint",
        "text-primary-ink",
        "size-[84px]",
        "hero-chevron-right"
      ])

      assert html =~ "/uploads/b_thumb.jpg"
      assert html =~ "Uses chicken, rice"
    end

    test "a need match lists the missing ingredients" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.row_card
          navigate="/posts/5"
          title="Ginger chicken rice bowls"
          match={{:need, 2}}
          missing={["soy sauce", "ginger"]}
        />
        """)

      assert html =~ "Need 2"
      assert html =~ "bg-accent/25"
      assert html =~ "missing:"
      assert html =~ "soy sauce, ginger"
      assert html =~ "bg-cream-lift"
      refute html =~ "<img"
    end
  end

  test "end_card/1 renders the mint card, check and copy" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.end_card title="You are caught up" message="That is everything from the last 7 days." />
      """)

    assert_classes(html, ["bg-mint-tint", "hero-check"])
    assert html =~ "You are caught up"
    assert html =~ "That is everything from the last 7 days."
  end

  describe "section_heading/1" do
    test "renders the title, aside and See all link" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.section_heading title="My recipes" aside="Newest first" see_all="/search" />
        """)

      assert html =~ "My recipes"
      assert html =~ "Newest first"
      assert html =~ ~s(href="/search")
      assert html =~ "See all"
      assert html =~ "font-display"
    end

    test "has no See all link without see_all" do
      assigns = %{}
      html = rendered_to_string(~H|<.section_heading title="Saved" />|)

      refute html =~ "See all"
    end
  end

  test "ingredient_chip/1 puts the remove event and label on its 32px button" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.ingredient_chip name="chicken" phx-click="remove-ingredient" phx-value-ingredient="chicken" />
      """)

    assert html =~ ~s(aria-label="Remove chicken")
    assert html =~ ~s(phx-click="remove-ingredient")
    assert html =~ ~s(phx-value-ingredient="chicken")
    assert_classes(html, ["size-8", "ring-accent/32", "bg-accent/25"])
  end

  test "recent_chip/1 renders an add button with a plus" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.recent_chip name="garlic" phx-click="add-ingredient" />
      """)

    assert html =~ ~s(aria-label="Add garlic")
    assert_classes(html, ["ring-border", "hero-plus"])
  end

  describe "empty_block/1" do
    test "card chrome sits on cream and renders its action" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_block title="Nothing saved yet." message="Save a recipe and it waits here.">
          <:action><a href="/search">Find recipes in Search</a></:action>
        </.empty_block>
        """)

      assert_classes(html, ["bg-cream-lift", "rounded-3xl"])
      assert html =~ "Nothing saved yet."
      assert html =~ "Find recipes in Search"
    end

    test "plain chrome has no card" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.empty_block title="No results yet." chrome={:plain} />
        """)

      refute html =~ "bg-cream-lift"
    end
  end

  test "skeleton_card/1 and skeleton_row/1 pulse only without Reduce Motion" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.skeleton_card aspect="1:1" />
      <.skeleton_row />
      """)

    assert html =~ ~s(aria-hidden="true")
    assert_classes(html, ["animate-pulse", "motion-reduce:animate-none", "aspect-square"])
  end

  describe "buttons" do
    test "primary_button renders a link with navigate and a button without" do
      assigns = %{}

      link = rendered_to_string(~H|<.primary_button navigate="/posts/new">Post</.primary_button>|)
      button = rendered_to_string(~H|<.primary_button type="submit">Save</.primary_button>|)

      assert link =~ "<a"
      assert link =~ ~s(href="/posts/new")
      assert button =~ "<button"
      assert_classes(button, ["bg-primary", "text-primary-content", "min-h-[50px]"])
    end

    test "secondary and accent buttons carry their variant classes" do
      assigns = %{}

      secondary = rendered_to_string(~H|<.secondary_button>Cancel</.secondary_button>|)
      accent = rendered_to_string(~H|<.accent_button wide>Try Trays Plus</.accent_button>|)

      assert_classes(secondary, ["bg-base-100", "ring-hairline-strong"])
      assert_classes(accent, ["bg-accent", "text-accent-content", "w-full"])
    end

    test "follow_button reflects the following state" do
      assigns = %{}

      follow = rendered_to_string(~H|<.follow_button following={false} />|)
      following = rendered_to_string(~H|<.follow_button following={true} />|)

      assert follow =~ "Follow"
      assert follow =~ ~s(aria-pressed="false")
      assert follow =~ "bg-primary"
      assert following =~ "Following"
      assert following =~ ~s(aria-pressed="true")
      assert following =~ "bg-base-300"
    end
  end
end
