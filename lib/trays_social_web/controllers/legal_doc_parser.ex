defmodule TraysSocialWeb.LegalDocParser do
  @moduledoc false

  # Parses a legal-doc markdown file with optional YAML-style frontmatter into
  # a struct of {effective_date, version, body_html}. Used at compile time by
  # `TraysSocialWeb.LegalController` to embed rendered HTML into a module
  # attribute so requests serve cached HTML with no per-request parsing.

  def parse(path) do
    raw = File.read!(path)
    {frontmatter, body_md} = split_frontmatter(raw)
    {:ok, body_html, _} = Earmark.as_html(body_md, gfm_tables: true, breaks: false)

    %{
      effective_date: frontmatter["effective_date"] || "unknown",
      version: frontmatter["version"] || "1.0",
      body_html: body_html
    }
  end

  defp split_frontmatter("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [front, body] -> {parse_yaml_kv(front), body}
      [body] -> {%{}, body}
    end
  end

  defp split_frontmatter(raw), do: {%{}, raw}

  defp parse_yaml_kv(yaml) do
    yaml
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
        _ -> acc
      end
    end)
  end
end
