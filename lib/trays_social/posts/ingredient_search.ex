defmodule TraysSocial.Posts.IngredientSearch do
  @moduledoc """
  "What I have" search: rank recipes by how few non-basic ingredients the
  viewer is missing. Matching is case-insensitive substring matching on
  ingredient names, so "chicken" also matches "chicken stock" (accepted v1
  imprecision; see the recipe-first spec, section 4).
  """

  import Ecto.Query, warn: false

  alias TraysSocial.Posts
  alias TraysSocial.Posts.Ingredient
  alias TraysSocial.Posts.Post
  alias TraysSocial.Repo

  @max_terms 10
  @max_term_length 50
  @max_missing 3
  @control_chars ~r/[\x00-\x1F\x7F]/
  @result_limit 50
  # Candidates are fetched newest first and ranked in Elixir. Revisit with a
  # SQL-side ranking if the catalog outgrows this window.
  @candidate_limit 500

  @pantry_basics MapSet.new([
                   "salt",
                   "kosher salt",
                   "sea salt",
                   "table salt",
                   "pepper",
                   "black pepper",
                   "ground black pepper",
                   "salt and pepper",
                   "water",
                   "oil",
                   "olive oil",
                   "extra virgin olive oil",
                   "vegetable oil",
                   "canola oil",
                   "cooking spray"
                 ])

  @scope_rank %{mine: 0, following: 1, everyone: 2}
  @preloads [:user, :ingredients, :tools, :cooking_steps, :post_tags, :post_photos]

  @type scope :: :mine | :following | :everyone
  @type result :: %{post: %Post{}, missing: [String.t()], scope: scope()}

  @doc """
  Normalizes raw ingredient chips: lowercased, trimmed, whitespace collapsed,
  singularized and deduplicated. Accepts 1 to #{@max_terms} terms of at most
  #{@max_term_length} characters each, valid UTF-8 with no control characters.
  """
  @spec normalize_terms(term()) :: {:ok, [String.t()]} | {:error, :invalid_ingredients}
  def normalize_terms(raw) when is_list(raw) do
    raw
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&normalize_term/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> validate_terms()
  end

  def normalize_terms(_raw), do: {:error, :invalid_ingredients}

  defp validate_terms(terms) do
    if valid_terms?(terms), do: {:ok, terms}, else: {:error, :invalid_ingredients}
  end

  defp valid_terms?(terms) do
    terms != [] and length(terms) <= @max_terms and Enum.all?(terms, &valid_term?/1)
  end

  # Postgres rejects NUL bytes and invalid UTF-8 in a text parameter with a
  # raised Postgrex.Error, so such a chip must fail validation here (a 422)
  # rather than reach the ILIKE query (a 500). Other control characters have no
  # business in an ingredient name either; whitespace ones were already
  # collapsed to spaces by squish/1.
  defp valid_term?(term) do
    String.valid?(term) and String.length(term) <= @max_term_length and
      not String.match?(term, @control_chars)
  end

  defp normalize_term(term), do: term |> squish() |> singularize()

  defp squish(text) do
    text
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp singularize(term) do
    cond do
      String.ends_with?(term, "oes") ->
        String.slice(term, 0..-3//1)

      String.length(term) > 3 and String.ends_with?(term, "s") and
          not String.ends_with?(term, "ss") ->
        String.slice(term, 0..-2//1)

      true ->
        term
    end
  end

  @doc "True when an ingredient name is a pantry basic that never counts as missing."
  @spec basic?(String.t()) :: boolean()
  def basic?(name) when is_binary(name), do: MapSet.member?(@pantry_basics, squish(name))

  @doc """
  Splits a recipe's ingredient names into what the terms cover and what is
  missing. Returns `{:ok, missing}` in recipe order, or `:no_match` when no
  non-basic ingredient matches any term.
  """
  @spec classify([String.t()], [String.t()]) :: {:ok, [String.t()]} | :no_match
  def classify(ingredient_names, terms) do
    {had, missing} =
      ingredient_names
      |> Enum.reject(&basic?/1)
      |> Enum.split_with(&matches_any?(&1, terms))

    if had == [], do: :no_match, else: {:ok, missing}
  end

  defp matches_any?(name, terms) do
    downcased = String.downcase(name)
    Enum.any?(terms, &String.contains?(downcased, &1))
  end

  @doc false
  @spec like_patterns([String.t()]) :: [String.t()]
  def like_patterns(terms), do: Enum.map(terms, &"%#{sanitize_like(&1)}%")

  @doc """
  Ranks recipes the viewer can make from `terms`. Callers should pass terms
  through `normalize_terms/1` first, which enforces the term count and length
  limits; terms are lowercased here either way.

  Opts: `:blocked_user_ids` (required, so a caller cannot forget blocks: pass
  `Accounts.blocked_pair_ids/1` for the viewer), `:following_ids`, and
  `:candidate_limit` (default #{@candidate_limit}, the newest matching recipes
  considered for ranking).
  Recipes missing more than #{@max_missing} ingredients are dropped; at most
  #{@result_limit} results are returned.
  """
  @spec search(pos_integer(), [String.t()], keyword()) :: %{
          everything: [result()],
          almost: [result()]
        }
  def search(viewer_id, terms, opts \\ []) do
    terms = Enum.map(terms, &String.downcase/1)

    candidates =
      candidate_posts(
        terms,
        Keyword.fetch!(opts, :blocked_user_ids),
        Keyword.get(opts, :candidate_limit, @candidate_limit)
      )

    ctx = rank_context(viewer_id, candidates, opts)

    {everything, almost} =
      candidates
      |> Enum.flat_map(&to_result(&1, terms, ctx))
      |> Enum.sort_by(&sort_key/1)
      |> Enum.take(@result_limit)
      |> Enum.split_with(&(&1.missing == []))

    %{everything: everything, almost: almost}
  end

  defp rank_context(viewer_id, candidates, opts) do
    candidate_ids = Enum.map(candidates, & &1.id)

    %{
      viewer_id: viewer_id,
      following: opts |> Keyword.get(:following_ids, []) |> MapSet.new(),
      bookmarked: Posts.bookmarked_post_ids_for_user(viewer_id, candidate_ids)
    }
  end

  defp to_result(post, terms, ctx) do
    case post |> ingredient_names() |> classify(terms) do
      {:ok, missing} when length(missing) <= @max_missing ->
        [%{post: post, missing: missing, scope: scope_for(post, ctx)}]

      _other ->
        []
    end
  end

  # Ingredients have no preload order, so sort explicitly to keep "missing"
  # in the order the recipe lists them.
  defp ingredient_names(post) do
    post.ingredients
    |> Enum.sort_by(&{&1.order || 0, &1.id})
    |> Enum.map(& &1.name)
  end

  defp scope_for(post, %{viewer_id: viewer_id, bookmarked: bookmarked, following: following}) do
    cond do
      post.user_id == viewer_id -> :mine
      MapSet.member?(bookmarked, post.id) -> :mine
      MapSet.member?(following, post.user_id) -> :following
      true -> :everyone
    end
  end

  defp sort_key(%{post: post, missing: missing, scope: scope}) do
    {length(missing), Map.fetch!(@scope_rank, scope), -DateTime.to_unix(post.inserted_at),
     -post.id}
  end

  defp candidate_posts(terms, blocked_ids, candidate_limit) do
    patterns = like_patterns(terms)

    ingredient_match =
      from(i in Ingredient,
        where: i.post_id == parent_as(:post).id and fragment("? ILIKE ANY(?)", i.name, ^patterns)
      )

    from(p in Post, as: :post)
    |> where([p], is_nil(p.deleted_at) and is_nil(p.removed_at) and p.type == "recipe")
    |> where([p], exists(ingredient_match))
    |> exclude_blocked(blocked_ids)
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> limit(^candidate_limit)
    |> Repo.all()
    |> Repo.preload(@preloads)
  end

  defp exclude_blocked(query, []), do: query
  defp exclude_blocked(query, ids), do: where(query, [p], p.user_id not in ^ids)

  # Same escaping as the private Posts.sanitize_like/1.
  defp sanitize_like(string) do
    string
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
