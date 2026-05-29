defmodule TraysSocial.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.

  W111: `seed_demo/0` seeds the three demo accounts an App Reviewer logs
  in with to evaluate the app. Callable from a release shell via:

      bin/trays_social eval "TraysSocial.Release.seed_demo()"

  See docs/demo-seed.md for the operator workflow.
  """
  @app :trays_social

  import Ecto.Query

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.{Follow, User}
  alias TraysSocial.Posts

  alias TraysSocial.Posts.{Comment, Post, PostLike}

  alias TraysSocial.Repo

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  W111: idempotent demo seed. Creates the three demo accounts an App
  Reviewer logs in with. Re-running does NOT create duplicates — users
  are looked up by username, posts by user + caption, follows + likes +
  comments by their natural unique keys.

  Requires `DEMO_USER_PASSWORD` (>= 12 chars) on the release env. Refuses
  to run without it so an operator can't accidentally seed prod with a
  guessable password.
  """
  def seed_demo do
    load_app()
    password = require_demo_password!()

    # Start the FULL supervision tree, not just the Repo. The seed calls
    # real context functions — follow_user/2 -> create_notification/1 ->
    # Phoenix.PubSub.broadcast/4 — and the named TraysSocial.PubSub process
    # only exists when the app is started. `bin/<app> eval` boots the code
    # but does NOT start the application, so a Repo-only start (the old
    # with_repo wrapper) crashed at the first follow with "unknown registry:
    # TraysSocial.PubSub" (prod, 2026-05-29). The Endpoint stays server:
    # false here because PHX_SERVER is unset under eval, so no port is bound.
    {:ok, _apps} = Application.ensure_all_started(:trays_social)

    do_seed_demo(password)
  end

  defp require_demo_password! do
    case System.get_env("DEMO_USER_PASSWORD") do
      pw when is_binary(pw) and byte_size(pw) >= 12 ->
        pw

      _ ->
        raise """
        TraysSocial.Release.seed_demo/0 requires DEMO_USER_PASSWORD env var
        (minimum 12 characters). Set it via:

            fly secrets set DEMO_USER_PASSWORD=<a strong password>

        then re-run.
        """
    end
  end

  # Internal-public so the seed logic can be exercised under the test
  # sandbox without the `with_repo`/env-var wrapper in seed_demo/0.
  # Not part of the public API — call seed_demo/0 in production.
  @doc false
  def do_seed_demo(password) do
    alice =
      upsert_demo_user(
        "demo_alice",
        "demo_alice@trays.app",
        "Weekend brunch cook. Mostly eggs and pastry.",
        password
      )

    ben =
      upsert_demo_user(
        "demo_ben",
        "demo_ben@trays.app",
        "Grills, smoke, and slow-and-low.",
        password
      )

    chloe =
      upsert_demo_user(
        "demo_chloe",
        "demo_chloe@trays.app",
        "Plant-forward weeknight cooking, big on flavor.",
        password
      )

    Enum.each(alice_posts(), &upsert_demo_post(alice, &1))
    Enum.each(ben_posts(), &upsert_demo_post(ben, &1))
    Enum.each(chloe_posts(), &upsert_demo_post(chloe, &1))

    # Mutual follows — all three follow each other.
    for {follower, followed} <- [
          {alice, ben},
          {alice, chloe},
          {ben, alice},
          {ben, chloe},
          {chloe, alice},
          {chloe, ben}
        ] do
      ensure_follow(follower, followed)
    end

    seed_cross_likes([alice, ben, chloe])
    seed_cross_comments([alice, ben, chloe])

    IO.puts("[seed_demo] OK — demo_alice, demo_ben, demo_chloe ready")
    :ok
  end

  # --- Users --------------------------------------------------------

  defp upsert_demo_user(username, email, bio, password) do
    user =
      case Repo.get_by(User, username: username) do
        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              email: email,
              username: username,
              password: password,
              bio: bio,
              # Required by the registration changeset (validate_acceptance);
              # the demo cooks are operator-seeded fixtures, so the 13+
              # attestation is affirmed on their behalf — same as the test
              # fixtures and the API/Apple registration paths.
              age_confirmation: true
            })

          user

        %User{} = user ->
          user
      end

    ensure_demo_credentials(user, password)
  end

  # The DEMO_USER_PASSWORD secret is the single source of truth for demo
  # logins. On every seed run we (1) reset the account password to the
  # current secret and (2) ensure the account is email-confirmed. This makes
  # fixing a demo account a one-liner — set the secret, re-run seed_demo —
  # with no delete-and-reseed, and it self-heals accounts seeded by older
  # versions of this task (wrong/unknown password, or unconfirmed).
  #
  # Confirmation matters because the API gates posting/commenting behind it
  # and demo_*@trays.app can't receive a confirmation link, so an unconfirmed
  # demo account leaves an App Reviewer unable to exercise the core flows.
  defp ensure_demo_credentials(%User{} = user, password) do
    user
    |> reset_password(password)
    |> ensure_confirmed()
  end

  defp reset_password(%User{} = user, password) do
    {:ok, user} = Repo.update(User.password_changeset(user, %{password: password}))
    user
  end

  defp ensure_confirmed(%User{confirmed_at: nil} = user) do
    {:ok, user} = Repo.update(User.confirm_changeset(user))
    user
  end

  defp ensure_confirmed(%User{} = user), do: user

  # --- Posts --------------------------------------------------------

  defp upsert_demo_post(%User{} = user, %{caption: caption} = data) do
    case Repo.get_by(Post, user_id: user.id, caption: caption) do
      %Post{} = post ->
        post

      nil ->
        # Build the full nested post in one create_post/2 call. change_post/2
        # cast_assoc's ingredients, tools, cooking_steps, post_tags, and
        # post_photos and requires photo_url + at-least-one ingredient and
        # cooking step, so the children must be present at insert time —
        # creating the post first and inserting children separately fails
        # those validations (the W111 prod-seed failure on 2026-05-29).
        {:ok, post} = Posts.create_post(user.id, build_post_attrs(caption, data))
        post
    end
  end

  defp build_post_attrs(caption, data) do
    %{
      type: "recipe",
      caption: caption,
      cooking_time_minutes: Map.get(data, :cooking_time_minutes),
      servings: Map.get(data, :servings),
      photo_url: data[:photo_url],
      ingredients:
        data[:ingredients]
        |> List.wrap()
        |> Enum.with_index()
        |> Enum.map(fn {ingr, idx} -> Map.put(ingr, :order, idx) end),
      cooking_steps:
        data[:cooking_steps]
        |> List.wrap()
        |> Enum.with_index()
        |> Enum.map(fn {step, idx} -> %{description: step, order: idx} end),
      tools:
        data[:tools]
        |> List.wrap()
        |> Enum.with_index()
        |> Enum.map(fn {tool, idx} -> %{name: tool, order: idx} end),
      post_tags: data[:tags] |> List.wrap() |> Enum.map(&%{tag: &1}),
      post_photos:
        case data[:photo_url] do
          url when is_binary(url) -> [%{url: url, position: 0}]
          _ -> []
        end
    }
  end

  # --- Follows / Likes / Comments ----------------------------------

  defp ensure_follow(%User{} = follower, %User{} = followed) do
    case Repo.get_by(Follow, follower_id: follower.id, followed_id: followed.id) do
      %Follow{} -> :ok
      nil -> Accounts.follow_user(follower, followed)
    end
  end

  defp seed_cross_likes(users) do
    [alice, ben, chloe] = users
    alice_posts_loaded = posts_by_user(alice)
    ben_posts_loaded = posts_by_user(ben)
    chloe_posts_loaded = posts_by_user(chloe)

    # Each cook likes the first two posts of the other two cooks
    # = 12 distinct (user, post) pairs, satisfying the >= 10 AC.
    Enum.each(Enum.take(ben_posts_loaded, 2), &ensure_like(alice, &1))
    Enum.each(Enum.take(chloe_posts_loaded, 2), &ensure_like(alice, &1))
    Enum.each(Enum.take(alice_posts_loaded, 2), &ensure_like(ben, &1))
    Enum.each(Enum.take(chloe_posts_loaded, 2), &ensure_like(ben, &1))
    Enum.each(Enum.take(alice_posts_loaded, 2), &ensure_like(chloe, &1))
    Enum.each(Enum.take(ben_posts_loaded, 2), &ensure_like(chloe, &1))
  end

  defp ensure_like(%User{} = user, %Post{} = post) do
    case Repo.get_by(PostLike, user_id: user.id, post_id: post.id) do
      %PostLike{} -> :ok
      nil -> Posts.like_post(post, user)
    end
  end

  defp seed_cross_comments(users) do
    [alice, ben, chloe] = users
    alice_posts_loaded = posts_by_user(alice)
    ben_posts_loaded = posts_by_user(ben)
    chloe_posts_loaded = posts_by_user(chloe)

    # Six distinct cross-comments so each cook leaves notes on both of
    # the other two cooks' lead posts.
    ensure_comment(alice, hd(ben_posts_loaded), "Tried this — your brine made all the difference.")
    ensure_comment(alice, hd(chloe_posts_loaded), "Adding this to the rotation. Love a sturdy weeknight bowl.")
    ensure_comment(ben, hd(alice_posts_loaded), "Swapped in scallions and it ran perfectly.")
    ensure_comment(ben, hd(chloe_posts_loaded), "Skipped the chili crisp once. Won't do that again.")
    ensure_comment(chloe, hd(alice_posts_loaded), "Eggs benedict in 30 — I owe you one.")
    ensure_comment(chloe, hd(ben_posts_loaded), "Smoked this Sunday. Family agreed: best of the year.")
  end

  defp ensure_comment(%User{} = user, %Post{} = post, body) do
    case Repo.get_by(Comment, user_id: user.id, post_id: post.id, body: body) do
      %Comment{} -> :ok
      nil -> Posts.create_comment(post, user, %{body: body})
    end
  end

  # --- Helpers ------------------------------------------------------

  defp posts_by_user(%User{} = user) do
    Post
    |> where([p], p.user_id == ^user.id and is_nil(p.deleted_at) and is_nil(p.removed_at))
    |> order_by([p], asc: p.id)
    |> Repo.all()
  end

  # --- Demo content -------------------------------------------------

  # Photo URLs point at Unsplash (consistent with priv/repo/seeds.exs).
  # Recipes are deliberately short — an App Reviewer skims them in
  # seconds, so density beats prose.

  defp alice_posts do
    [
      %{
        caption: "Eggs Benedict for two in 30 minutes flat",
        cooking_time_minutes: 30,
        servings: 2,
        photo_url: "https://images.unsplash.com/photo-1551534962-58e3a0c4d0d2?w=800",
        tags: ["breakfast", "brunch", "eggs"],
        ingredients: [
          %{name: "English muffins", quantity: "2", unit: "split"},
          %{name: "Canadian bacon", quantity: "4", unit: "slices"},
          %{name: "Eggs", quantity: "4", unit: "large"},
          %{name: "Butter", quantity: "0.5", unit: "cup"},
          %{name: "Egg yolks", quantity: "3", unit: "large"},
          %{name: "Lemon juice", quantity: "1", unit: "tbsp"}
        ],
        cooking_steps: [
          "Melt butter and keep warm. Toast muffin halves.",
          "Crisp bacon in a dry pan and rest.",
          "Whisk yolks + lemon juice over a bain-marie until ribbons form.",
          "Stream warm butter into yolks, whisking, until thick. Season.",
          "Poach eggs 3 minutes in lightly vinegared simmering water.",
          "Stack: muffin, bacon, egg, generous spoon of hollandaise."
        ],
        tools: ["Saucepan", "Whisk", "Slotted spoon", "Skillet"]
      },
      %{
        caption: "Buttermilk scones with cold butter and a hot oven",
        cooking_time_minutes: 35,
        servings: 8,
        photo_url: "https://images.unsplash.com/photo-1517686469429-8bdb88b9f907?w=800",
        tags: ["brunch", "baking", "scones"],
        ingredients: [
          %{name: "All-purpose flour", quantity: "2.5", unit: "cups"},
          %{name: "Sugar", quantity: "0.25", unit: "cup"},
          %{name: "Baking powder", quantity: "1", unit: "tbsp"},
          %{name: "Salt", quantity: "0.5", unit: "tsp"},
          %{name: "Cold butter", quantity: "0.5", unit: "cup"},
          %{name: "Buttermilk", quantity: "0.75", unit: "cup"}
        ],
        cooking_steps: [
          "Heat oven to 425F. Line a sheet pan.",
          "Whisk dry ingredients. Cut in butter to pea-sized crumbs.",
          "Stir in buttermilk just until shaggy. Don't overwork.",
          "Pat into a 1-inch round and cut into 8 wedges.",
          "Bake 15-18 minutes until tops are gold and cracked."
        ],
        tools: ["Sheet pan", "Bowl", "Bench scraper", "Pastry cutter"]
      },
      %{
        caption: "Sourdough pancakes — light, tangy, no buttermilk",
        cooking_time_minutes: 25,
        servings: 4,
        photo_url: "https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=800",
        tags: ["breakfast", "sourdough", "pancakes"],
        ingredients: [
          %{name: "Sourdough discard", quantity: "1", unit: "cup"},
          %{name: "All-purpose flour", quantity: "1", unit: "cup"},
          %{name: "Milk", quantity: "0.75", unit: "cup"},
          %{name: "Eggs", quantity: "2", unit: "large"},
          %{name: "Sugar", quantity: "2", unit: "tbsp"},
          %{name: "Baking soda", quantity: "1", unit: "tsp"},
          %{name: "Butter", quantity: "3", unit: "tbsp"}
        ],
        cooking_steps: [
          "Whisk discard, flour, milk in a bowl. Rest 10 minutes.",
          "Beat in eggs, melted butter, sugar, baking soda.",
          "Drop 1/4 cup pours onto a hot greased skillet.",
          "Flip when bubbles open on the surface — about 2 minutes a side."
        ],
        tools: ["Skillet", "Whisk", "Mixing bowl", "Ladle"]
      },
      %{
        caption: "Lemon ricotta toast with honey and thyme",
        cooking_time_minutes: 10,
        servings: 2,
        photo_url: "https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800",
        tags: ["breakfast", "easy", "no-cook"],
        ingredients: [
          %{name: "Country bread", quantity: "2", unit: "thick slices"},
          %{name: "Whole-milk ricotta", quantity: "0.5", unit: "cup"},
          %{name: "Lemon zest", quantity: "1", unit: "lemon"},
          %{name: "Honey", quantity: "2", unit: "tbsp"},
          %{name: "Fresh thyme", quantity: "0.5", unit: "tsp"}
        ],
        cooking_steps: [
          "Toast the bread until properly browned, not just dry.",
          "Whip ricotta with lemon zest and a pinch of salt.",
          "Spread thickly, drizzle honey, scatter thyme.",
          "Eat standing up."
        ],
        tools: ["Toaster", "Bowl", "Spoon", "Microplane"]
      },
      %{
        caption: "Quiche Lorraine without the fuss",
        cooking_time_minutes: 70,
        servings: 6,
        photo_url: "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800",
        tags: ["brunch", "french", "savory"],
        ingredients: [
          %{name: "Pie shell", quantity: "1", unit: "9-inch"},
          %{name: "Bacon", quantity: "6", unit: "strips"},
          %{name: "Eggs", quantity: "4", unit: "large"},
          %{name: "Heavy cream", quantity: "1.5", unit: "cups"},
          %{name: "Gruyere", quantity: "1", unit: "cup grated"},
          %{name: "Nutmeg", quantity: "1", unit: "pinch"}
        ],
        cooking_steps: [
          "Heat oven to 375F. Blind-bake shell 10 minutes.",
          "Render bacon, chop, scatter in shell with most of the cheese.",
          "Whisk eggs, cream, nutmeg, salt, pepper. Pour over.",
          "Top with remaining cheese. Bake 35-40 minutes until set.",
          "Rest 15 minutes before slicing — the custard finishes off-heat."
        ],
        tools: ["Pie dish", "Whisk", "Bowl", "Knife"]
      }
    ]
  end

  defp ben_posts do
    [
      %{
        caption: "Smoked brisket — overnight, no shortcuts",
        cooking_time_minutes: 720,
        servings: 8,
        photo_url: "https://images.unsplash.com/photo-1544025162-d76694265947?w=800",
        tags: ["bbq", "smoked", "dinner"],
        ingredients: [
          %{name: "Whole packer brisket", quantity: "12", unit: "lb"},
          %{name: "Coarse salt", quantity: "0.25", unit: "cup"},
          %{name: "Coarse black pepper", quantity: "0.25", unit: "cup"},
          %{name: "Hickory chunks", quantity: "4", unit: "fist-sized"}
        ],
        cooking_steps: [
          "Trim the fat cap to 1/4 inch. Score lightly.",
          "Rub with salt and pepper. Rest 30 minutes.",
          "Smoke at 225F fat-side up until 165F internal — about 6 hours.",
          "Wrap in butcher paper, return to smoker until 203F probe-tender.",
          "Rest in a cooler for at least 1 hour. Slice against the grain."
        ],
        tools: ["Smoker", "Probe thermometer", "Butcher paper", "Sharp knife"]
      },
      %{
        caption: "Buttermilk fried chicken on a Tuesday",
        cooking_time_minutes: 60,
        servings: 4,
        photo_url: "https://images.unsplash.com/photo-1562967914-608f82629710?w=800",
        tags: ["fried", "comfort", "weeknight"],
        ingredients: [
          %{name: "Chicken thighs", quantity: "8", unit: "bone-in skin-on"},
          %{name: "Buttermilk", quantity: "2", unit: "cups"},
          %{name: "Hot sauce", quantity: "2", unit: "tbsp"},
          %{name: "All-purpose flour", quantity: "2", unit: "cups"},
          %{name: "Paprika", quantity: "1", unit: "tbsp"},
          %{name: "Cayenne", quantity: "1", unit: "tsp"},
          %{name: "Neutral oil", quantity: "4", unit: "cups"}
        ],
        cooking_steps: [
          "Brine chicken in buttermilk + hot sauce 4 hours or overnight.",
          "Whisk flour with paprika, cayenne, salt, pepper.",
          "Drag chicken from brine straight into seasoned flour. Press.",
          "Fry at 325F until 165F internal — about 12 minutes a side.",
          "Drain on a wire rack. Salt while hot."
        ],
        tools: ["Dutch oven", "Wire rack", "Thermometer", "Tongs"]
      },
      %{
        caption: "Smash burger on a flat top",
        cooking_time_minutes: 20,
        servings: 2,
        photo_url: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800",
        tags: ["burger", "weeknight", "beef"],
        ingredients: [
          %{name: "80/20 ground beef", quantity: "0.5", unit: "lb"},
          %{name: "Brioche buns", quantity: "2", unit: "split"},
          %{name: "American cheese", quantity: "4", unit: "slices"},
          %{name: "Yellow onion", quantity: "0.5", unit: "thin-sliced"},
          %{name: "Pickles", quantity: "8", unit: "rounds"},
          %{name: "Salt", quantity: "1", unit: "tsp"}
        ],
        cooking_steps: [
          "Heat flat top or cast iron to ripping hot.",
          "Loosely form beef into 4 balls. Salt.",
          "Smash hard, top with onion, salt again.",
          "Flip when edges crisp. Cheese on. Stack two patties per bun.",
          "Top with pickles. Eat immediately."
        ],
        tools: ["Cast-iron pan", "Smasher", "Spatula"]
      },
      %{
        caption: "Carolina-style pulled pork shoulder",
        cooking_time_minutes: 480,
        servings: 10,
        photo_url: "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=800",
        tags: ["bbq", "pork", "low-and-slow"],
        ingredients: [
          %{name: "Pork shoulder", quantity: "8", unit: "lb bone-in"},
          %{name: "Yellow mustard", quantity: "0.25", unit: "cup"},
          %{name: "Brown sugar", quantity: "0.25", unit: "cup"},
          %{name: "Smoked paprika", quantity: "2", unit: "tbsp"},
          %{name: "Apple cider vinegar", quantity: "1", unit: "cup"},
          %{name: "Salt + pepper", quantity: "to", unit: "taste"}
        ],
        cooking_steps: [
          "Slather pork with mustard. Pack on sugar, paprika, salt, pepper.",
          "Smoke at 250F until bark sets — about 4 hours.",
          "Wrap in foil with a splash of vinegar; continue to 203F internal.",
          "Rest 1 hour. Pull. Toss with more vinegar to taste."
        ],
        tools: ["Smoker", "Probe thermometer", "Foil", "Forks"]
      },
      %{
        caption: "Skillet cornbread, crusty edges, tender middle",
        cooking_time_minutes: 30,
        servings: 8,
        photo_url: "https://images.unsplash.com/photo-1574323347407-f5e1c5a1ec21?w=800",
        tags: ["southern", "baking", "side"],
        ingredients: [
          %{name: "Cornmeal", quantity: "1.5", unit: "cups"},
          %{name: "All-purpose flour", quantity: "0.5", unit: "cup"},
          %{name: "Baking powder", quantity: "2", unit: "tsp"},
          %{name: "Buttermilk", quantity: "1.5", unit: "cups"},
          %{name: "Eggs", quantity: "2", unit: "large"},
          %{name: "Butter", quantity: "4", unit: "tbsp"}
        ],
        cooking_steps: [
          "Heat 10-inch cast iron in a 425F oven with the butter inside.",
          "Whisk dry ingredients. Whisk wet ingredients.",
          "Combine. Pour into the screaming-hot pan (it should sizzle).",
          "Bake 20-25 minutes until the center springs back."
        ],
        tools: ["Cast iron pan", "Whisk", "Mixing bowls"]
      }
    ]
  end

  defp chloe_posts do
    [
      %{
        caption: "Coconut chickpea curry that comes together in one pot",
        cooking_time_minutes: 30,
        servings: 4,
        photo_url: "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800",
        tags: ["vegan", "curry", "weeknight"],
        ingredients: [
          %{name: "Yellow onion", quantity: "1", unit: "diced"},
          %{name: "Garlic", quantity: "4", unit: "cloves minced"},
          %{name: "Ginger", quantity: "1", unit: "tbsp grated"},
          %{name: "Garam masala", quantity: "2", unit: "tsp"},
          %{name: "Tomato paste", quantity: "2", unit: "tbsp"},
          %{name: "Chickpeas", quantity: "2", unit: "cans drained"},
          %{name: "Full-fat coconut milk", quantity: "1", unit: "can"},
          %{name: "Spinach", quantity: "5", unit: "oz baby"}
        ],
        cooking_steps: [
          "Sweat onion in oil until translucent.",
          "Add garlic, ginger, garam masala. Bloom 30 seconds.",
          "Stir in tomato paste, then chickpeas and coconut milk.",
          "Simmer 12-15 minutes to thicken. Salt to taste.",
          "Wilt in spinach off-heat. Serve over rice."
        ],
        tools: ["Dutch oven", "Wooden spoon", "Knife", "Microplane"]
      },
      %{
        caption: "Cold soba with sesame, scallion, and cucumber",
        cooking_time_minutes: 15,
        servings: 2,
        photo_url: "https://images.unsplash.com/photo-1502301103665-0b95cc738daf?w=800",
        tags: ["japanese", "cold", "easy"],
        ingredients: [
          %{name: "Soba noodles", quantity: "200", unit: "g"},
          %{name: "Toasted sesame oil", quantity: "1", unit: "tbsp"},
          %{name: "Soy sauce", quantity: "2", unit: "tbsp"},
          %{name: "Rice vinegar", quantity: "1", unit: "tbsp"},
          %{name: "Cucumber", quantity: "1", unit: "thin-sliced"},
          %{name: "Scallions", quantity: "3", unit: "sliced"},
          %{name: "Sesame seeds", quantity: "1", unit: "tbsp"}
        ],
        cooking_steps: [
          "Boil soba per package, then shock in ice water and drain hard.",
          "Whisk sesame oil, soy, vinegar in the serving bowl.",
          "Toss noodles in the dressing. Add cucumber and most of the scallions.",
          "Top with sesame seeds and the remaining scallions."
        ],
        tools: ["Pot", "Strainer", "Bowl", "Whisk"]
      },
      %{
        caption: "Miso-glazed eggplant on rice",
        cooking_time_minutes: 25,
        servings: 2,
        photo_url: "https://images.unsplash.com/photo-1606756790138-261d2b21cd75?w=800",
        tags: ["vegan", "japanese", "rice"],
        ingredients: [
          %{name: "Japanese eggplant", quantity: "2", unit: "halved"},
          %{name: "White miso", quantity: "3", unit: "tbsp"},
          %{name: "Mirin", quantity: "2", unit: "tbsp"},
          %{name: "Sake", quantity: "1", unit: "tbsp"},
          %{name: "Sugar", quantity: "1", unit: "tbsp"},
          %{name: "Cooked short-grain rice", quantity: "2", unit: "bowls"},
          %{name: "Scallion", quantity: "1", unit: "sliced"}
        ],
        cooking_steps: [
          "Score eggplant flesh in a crosshatch.",
          "Roast cut-side down at 425F for 15 minutes until soft.",
          "Whisk miso, mirin, sake, sugar into a glaze.",
          "Flip eggplant, brush with glaze, broil 3-4 minutes until bubbling.",
          "Serve over rice. Garnish with scallion."
        ],
        tools: ["Sheet pan", "Whisk", "Brush", "Rice cooker"]
      },
      %{
        caption: "Sheet-pan harissa carrots with whipped feta",
        cooking_time_minutes: 30,
        servings: 4,
        photo_url: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800",
        tags: ["vegetarian", "mediterranean", "side"],
        ingredients: [
          %{name: "Carrots", quantity: "1.5", unit: "lb whole"},
          %{name: "Harissa paste", quantity: "2", unit: "tbsp"},
          %{name: "Olive oil", quantity: "3", unit: "tbsp"},
          %{name: "Feta", quantity: "200", unit: "g"},
          %{name: "Greek yogurt", quantity: "0.25", unit: "cup"},
          %{name: "Lemon", quantity: "1", unit: "juiced"},
          %{name: "Honey", quantity: "1", unit: "tbsp"}
        ],
        cooking_steps: [
          "Roast carrots tossed in oil, harissa, salt at 425F for 25 minutes.",
          "Whip feta with yogurt and lemon until silky.",
          "Spread feta on a platter. Pile carrots on top.",
          "Drizzle honey and a little more oil."
        ],
        tools: ["Sheet pan", "Food processor", "Spatula"]
      },
      %{
        caption: "Crispy tofu with chili crisp and broccolini",
        cooking_time_minutes: 25,
        servings: 2,
        photo_url: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800",
        tags: ["vegan", "weeknight", "spicy"],
        ingredients: [
          %{name: "Extra-firm tofu", quantity: "1", unit: "block pressed"},
          %{name: "Cornstarch", quantity: "3", unit: "tbsp"},
          %{name: "Broccolini", quantity: "1", unit: "bunch"},
          %{name: "Garlic", quantity: "3", unit: "cloves sliced"},
          %{name: "Soy sauce", quantity: "2", unit: "tbsp"},
          %{name: "Chili crisp", quantity: "2", unit: "tbsp"},
          %{name: "Cooked rice", quantity: "2", unit: "bowls"}
        ],
        cooking_steps: [
          "Cube tofu. Toss in cornstarch + salt.",
          "Fry in a thin layer of oil until each side is mahogany.",
          "Push to the side; quick-blister broccolini with the garlic.",
          "Off-heat, toss everything with soy and chili crisp.",
          "Serve over rice."
        ],
        tools: ["Cast iron pan", "Tongs", "Knife"]
      }
    ]
  end

  # --- Boilerplate --------------------------------------------------

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
