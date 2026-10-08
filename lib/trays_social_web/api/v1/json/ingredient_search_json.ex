defmodule TraysSocialWeb.API.V1.JSON.IngredientSearchJSON do
  @moduledoc """
  JSON rendering for "What I have" ingredient search results in API v1.

  Each result is `{post, missing, scope}`: the full PostJSON post, the
  non-basic ingredients the viewer lacks (in recipe order), and the scope
  string ("mine", "following" or "everyone").
  """

  alias TraysSocialWeb.API.V1.JSON.PostJSON

  def render(%{everything: everything, almost: almost}, opts) do
    %{
      everything: Enum.map(everything, &render_result(&1, opts)),
      almost: Enum.map(almost, &render_result(&1, opts))
    }
  end

  defp render_result(%{post: post, missing: missing, scope: scope}, opts) do
    %{post: PostJSON.render(post, opts), missing: missing, scope: Atom.to_string(scope)}
  end
end
