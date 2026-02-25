import Ecto.Query
alias TraysSocial.Repo
alias TraysSocial.Accounts.User
alias TraysSocial.Posts.{Post, Ingredient, CookingStep, Tool, PostTag}

Repo.delete_all(PostTag)
Repo.delete_all(CookingStep)
Repo.delete_all(Tool)
Repo.delete_all(Ingredient)
Repo.delete_all(Post)
Repo.delete_all(User)

users = [
  %{
    email: "chef.maria@example.com",
    username: "chef_maria",
    bio: "Professional chef sharing family recipes",
    profile_photo_url: "https://images.unsplash.com/photo-1595273670150-bd0c3c392e46?w=400",
    password: "password123456"
  },
  %{
    email: "john.baker@example.com",
    username: "john_baker",
    bio: "Home baker passionate about bread and pastries",
    profile_photo_url: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400",
    password: "password123456"
  },
  %{
    email: "healthy.eats@example.com",
    username: "healthy_eats",
    bio: "Nutritious meals for busy people",
    profile_photo_url: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400",
    password: "password123456"
  },
  %{
    email: "spice.master@example.com",
    username: "spice_master",
    bio: "Exploring flavors from around the world",
    profile_photo_url: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400",
    password: "password123456"
  }
]

created_users = Enum.map(users, fn user_attrs ->
  {:ok, user} = 
    %User{}
    |> User.registration_changeset(user_attrs)
    |> Repo.insert()
  user
end)

[user1, user2, user3, user4] = created_users

posts_data = [
  %{
    user: user1,
    photo_url: "https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800",
    caption: "Homemade margherita pizza with fresh mozzarella and basil. The secret is in the dough - let it rise slowly!",
    cooking_time_minutes: 90,
    tags: ["italian", "pizza", "dinner"],
    ingredients: [
      %{name: "Pizza dough", quantity: "1", unit: "ball"},
      %{name: "San Marzano tomatoes", quantity: "400", unit: "g"},
      %{name: "Fresh mozzarella", quantity: "250", unit: "g"},
      %{name: "Fresh basil", quantity: "1", unit: "bunch"},
      %{name: "Olive oil", quantity: "2", unit: "tbsp"},
      %{name: "Salt", quantity: "1", unit: "tsp"}
    ],
    cooking_steps: [
      "Preheat oven to 475°F (245°C) with pizza stone inside",
      "Roll out pizza dough on floured surface to 12-inch circle",
      "Spread crushed tomatoes evenly, leaving 1-inch border",
      "Add torn mozzarella pieces across the pizza",
      "Drizzle with olive oil and season with salt",
      "Bake for 12-15 minutes until crust is golden",
      "Top with fresh basil leaves before serving"
    ],
    tools: ["Pizza stone", "Rolling pin", "Pizza peel", "Oven"]
  },
  %{
    user: user2,
    photo_url: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800",
    caption: "Fluffy sourdough pancakes for a perfect weekend breakfast. Using sourdough starter adds amazing depth of flavor!",
    cooking_time_minutes: 25,
    tags: ["breakfast", "sourdough", "pancakes"],
    ingredients: [
      %{name: "Sourdough starter discard", quantity: "1", unit: "cup"},
      %{name: "All-purpose flour", quantity: "1", unit: "cup"},
      %{name: "Milk", quantity: "1", unit: "cup"},
      %{name: "Eggs", quantity: "2", unit: "large"},
      %{name: "Baking soda", quantity: "1", unit: "tsp"},
      %{name: "Sugar", quantity: "2", unit: "tbsp"},
      %{name: "Salt", quantity: "0.5", unit: "tsp"},
      %{name: "Butter", quantity: "3", unit: "tbsp"}
    ],
    cooking_steps: [
      "Mix sourdough starter, flour, and milk in a bowl, let sit 10 minutes",
      "Whisk in eggs, melted butter, sugar, salt, and baking soda",
      "Heat griddle or pan over medium heat, grease lightly",
      "Pour 1/4 cup batter for each pancake",
      "Cook until bubbles form on surface, about 2-3 minutes",
      "Flip and cook until golden brown, another 2 minutes",
      "Serve hot with maple syrup and butter"
    ],
    tools: ["Griddle", "Mixing bowl", "Whisk", "Measuring cups", "Spatula"]
  },
  %{
    user: user3,
    photo_url: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800",
    caption: "Fresh and vibrant Buddha bowl packed with nutrients. Perfect meal prep option for the week!",
    cooking_time_minutes: 35,
    tags: ["healthy", "vegan", "mealprep", "bowl"],
    ingredients: [
      %{name: "Quinoa", quantity: "1", unit: "cup"},
      %{name: "Sweet potato", quantity: "1", unit: "large"},
      %{name: "Chickpeas", quantity: "400", unit: "g"},
      %{name: "Kale", quantity: "2", unit: "cups"},
      %{name: "Avocado", quantity: "1", unit: "whole"},
      %{name: "Tahini", quantity: "3", unit: "tbsp"},
      %{name: "Lemon juice", quantity: "2", unit: "tbsp"},
      %{name: "Olive oil", quantity: "2", unit: "tbsp"}
    ],
    cooking_steps: [
      "Cook quinoa according to package instructions",
      "Dice sweet potato and roast at 400°F for 25 minutes",
      "Drain and rinse chickpeas, toss with olive oil and spices, roast 20 minutes",
      "Massage kale with a little olive oil until tender",
      "Make tahini dressing by mixing tahini, lemon juice, and water",
      "Arrange quinoa, sweet potato, chickpeas, and kale in bowl",
      "Top with sliced avocado and drizzle with tahini dressing"
    ],
    tools: ["Baking sheet", "Pot", "Mixing bowl", "Knife", "Cutting board"]
  },
  %{
    user: user4,
    photo_url: "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800",
    caption: "Authentic Thai green curry with tender chicken and vegetables. The homemade curry paste makes all the difference!",
    cooking_time_minutes: 45,
    tags: ["thai", "curry", "dinner", "spicy"],
    ingredients: [
      %{name: "Chicken breast", quantity: "500", unit: "g"},
      %{name: "Green curry paste", quantity: "3", unit: "tbsp"},
      %{name: "Coconut milk", quantity: "400", unit: "ml"},
      %{name: "Thai basil", quantity: "1", unit: "bunch"},
      %{name: "Bell pepper", quantity: "1", unit: "large"},
      %{name: "Bamboo shoots", quantity: "200", unit: "g"},
      %{name: "Fish sauce", quantity: "2", unit: "tbsp"},
      %{name: "Palm sugar", quantity: "1", unit: "tbsp"}
    ],
    cooking_steps: [
      "Cut chicken into bite-sized pieces",
      "Heat oil in wok, fry curry paste until fragrant",
      "Add chicken and cook until no longer pink",
      "Pour in coconut milk and bring to simmer",
      "Add bell pepper and bamboo shoots, cook 10 minutes",
      "Season with fish sauce and palm sugar",
      "Stir in Thai basil just before serving"
    ],
    tools: ["Wok", "Knife", "Cutting board", "Wooden spoon"]
  },
  %{
    user: user1,
    photo_url: "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=800",
    caption: "Classic tiramisu - no bake dessert that's absolutely divine! Coffee and mascarpone heaven.",
    cooking_time_minutes: 30,
    tags: ["dessert", "italian", "nobake"],
    ingredients: [
      %{name: "Ladyfinger cookies", quantity: "24", unit: "pieces"},
      %{name: "Mascarpone cheese", quantity: "500", unit: "g"},
      %{name: "Eggs", quantity: "4", unit: "large"},
      %{name: "Sugar", quantity: "100", unit: "g"},
      %{name: "Espresso", quantity: "300", unit: "ml"},
      %{name: "Cocoa powder", quantity: "2", unit: "tbsp"},
      %{name: "Marsala wine", quantity: "2", unit: "tbsp"}
    ],
    cooking_steps: [
      "Separate egg yolks and whites into two bowls",
      "Beat yolks with sugar until pale and creamy",
      "Mix in mascarpone cheese and Marsala wine",
      "Whip egg whites to stiff peaks, fold into mascarpone mixture",
      "Dip ladyfingers quickly in espresso",
      "Layer dipped cookies in dish, spread mascarpone cream on top",
      "Repeat layers, dust with cocoa powder, chill 4 hours"
    ],
    tools: ["Mixing bowls", "Electric mixer", "9x13 dish", "Whisk"]
  },
  %{
    user: user2,
    photo_url: "https://images.unsplash.com/photo-1608039829572-78524f79c4c7?w=800",
    caption: "Crusty artisan sourdough bread with the perfect crumb! Nothing beats fresh homemade bread.",
    cooking_time_minutes: 480,
    tags: ["bread", "sourdough", "baking"],
    ingredients: [
      %{name: "Bread flour", quantity: "500", unit: "g"},
      %{name: "Water", quantity: "375", unit: "ml"},
      %{name: "Active sourdough starter", quantity: "100", unit: "g"},
      %{name: "Salt", quantity: "10", unit: "g"}
    ],
    cooking_steps: [
      "Mix flour and water, let autolyse for 1 hour",
      "Add sourdough starter and salt, mix thoroughly",
      "Perform stretch and folds every 30 minutes for 2 hours",
      "Bulk ferment at room temperature for 4-6 hours",
      "Shape into boule and place in banneton",
      "Cold ferment in fridge overnight",
      "Preheat dutch oven to 450°F, score bread and bake 45 minutes"
    ],
    tools: ["Dutch oven", "Banneton basket", "Bench scraper", "Lame", "Kitchen scale"]
  },
  %{
    user: user3,
    photo_url: "https://images.unsplash.com/photo-1623428187969-5da2dcea5ebf?w=800",
    caption: "Protein-packed overnight oats with berries. Prep 5 jars on Sunday for easy grab-and-go breakfasts!",
    cooking_time_minutes: 5,
    tags: ["breakfast", "healthy", "mealprep", "oats"],
    ingredients: [
      %{name: "Rolled oats", quantity: "0.5", unit: "cup"},
      %{name: "Greek yogurt", quantity: "0.5", unit: "cup"},
      %{name: "Milk", quantity: "0.5", unit: "cup"},
      %{name: "Chia seeds", quantity: "1", unit: "tbsp"},
      %{name: "Honey", quantity: "1", unit: "tbsp"},
      %{name: "Mixed berries", quantity: "0.5", unit: "cup"},
      %{name: "Almond butter", quantity: "1", unit: "tbsp"}
    ],
    cooking_steps: [
      "Combine oats, yogurt, milk, and chia seeds in jar",
      "Stir in honey and mix well",
      "Top with mixed berries",
      "Seal jar and refrigerate overnight or at least 4 hours",
      "In the morning, stir and add almond butter on top",
      "Enjoy cold or warm in microwave for 1 minute"
    ],
    tools: ["Mason jar", "Spoon"]
  },
  %{
    user: user4,
    photo_url: "https://images.unsplash.com/photo-1585032226651-759b368d7246?w=800",
    caption: "Spicy Korean kimchi fried rice - perfect way to use leftover rice! The crispy bottom is the best part.",
    cooking_time_minutes: 20,
    tags: ["korean", "rice", "spicy", "lunch"],
    ingredients: [
      %{name: "Day-old rice", quantity: "3", unit: "cups"},
      %{name: "Kimchi", quantity: "1", unit: "cup"},
      %{name: "Kimchi juice", quantity: "2", unit: "tbsp"},
      %{name: "Bacon", quantity: "100", unit: "g"},
      %{name: "Eggs", quantity: "2", unit: "large"},
      %{name: "Green onions", quantity: "2", unit: "stalks"},
      %{name: "Gochugaru", quantity: "1", unit: "tsp"},
      %{name: "Sesame oil", quantity: "1", unit: "tbsp"}
    ],
    cooking_steps: [
      "Chop kimchi and bacon into small pieces",
      "Cook bacon in hot pan until crispy",
      "Add kimchi and stir-fry for 2 minutes",
      "Add rice, breaking up clumps, stir-fry 5 minutes",
      "Mix in kimchi juice, gochugaru, and sesame oil",
      "Let rice crisp on bottom for 2-3 minutes",
      "Fry eggs separately and top rice, garnish with green onions"
    ],
    tools: ["Wok", "Spatula", "Small pan", "Knife", "Cutting board"]
  }
]

Enum.each(posts_data, fn post_data ->
  {:ok, post} = 
    %Post{}
    |> Post.changeset(%{
      user_id: post_data.user.id,
      photo_url: post_data.photo_url,
      caption: post_data.caption,
      cooking_time_minutes: post_data.cooking_time_minutes
    })
    |> Repo.insert()

  Enum.with_index(post_data.ingredients, fn ingredient_data, idx ->
    %Ingredient{}
    |> Ingredient.changeset(Map.put(ingredient_data, :post_id, post.id) |> Map.put(:order, idx))
    |> Repo.insert!()
  end)

  Enum.with_index(post_data.cooking_steps, fn step_desc, idx ->
    %CookingStep{}
    |> CookingStep.changeset(%{description: step_desc, order: idx, post_id: post.id})
    |> Repo.insert!()
  end)

  Enum.with_index(post_data.tools, fn tool_name, idx ->
    %Tool{}
    |> Tool.changeset(%{name: tool_name, order: idx, post_id: post.id})
    |> Repo.insert!()
  end)

  Enum.each(post_data.tags, fn tag ->
    %PostTag{}
    |> PostTag.changeset(%{tag: tag, post_id: post.id})
    |> Repo.insert!()
  end)
end)

IO.puts("Seeded #{length(created_users)} users and #{length(posts_data)} posts with ingredients, steps, tools, and tags!")
