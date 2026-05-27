defmodule TraysSocial.Repo.Migrations.AddSearchTrigramIndexes do
  @moduledoc """
  W132: replace the ILIKE-with-leading-wildcard full-table scans on
  posts.caption / ingredients.name / post_tags.tag with GIN trigram
  indexes so /api/v1/search stays under its p95 target as the data
  volume grows.

  ## Why pg_trgm

  Phoenix's existing search uses ILIKE '%query%' across three columns.
  A leading `%` means the standard B-tree index can't be used — every
  ILIKE degenerates to a sequential scan. `pg_trgm` builds a trigram
  inverted index that DOES support the leading-wildcard case: Postgres
  walks the trigram index to find candidate rows then re-checks them
  against the ILIKE filter.

  ## Production rollout

  Both the extension creation and the indexes use `CONCURRENTLY` so a
  prod migration does not lock the relevant tables. Ecto's migration
  runner needs `@disable_ddl_transaction true` + `@disable_migration_lock true`
  for the CONCURRENTLY path to work; both flags are set below.

  Note that `CREATE EXTENSION pg_trgm` requires database-superuser
  privileges. Fly's managed postgres ships with this extension already
  whitelisted; if a future deploy target lacks it, this migration will
  fail with a clear error rather than silently degrading search.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    execute(
      "CREATE EXTENSION IF NOT EXISTS pg_trgm",
      "DROP EXTENSION IF EXISTS pg_trgm"
    )

    create_if_not_exists index(
                          :posts,
                          ["caption gin_trgm_ops"],
                          name: :posts_caption_trgm_idx,
                          using: :gin,
                          concurrently: true
                        )

    create_if_not_exists index(
                          :ingredients,
                          ["name gin_trgm_ops"],
                          name: :ingredients_name_trgm_idx,
                          using: :gin,
                          concurrently: true
                        )

    create_if_not_exists index(
                          :post_tags,
                          ["tag gin_trgm_ops"],
                          name: :post_tags_tag_trgm_idx,
                          using: :gin,
                          concurrently: true
                        )
  end
end
