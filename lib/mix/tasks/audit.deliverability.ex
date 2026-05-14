defmodule Mix.Tasks.Audit.Deliverability do
  @moduledoc """
  Audits DNS records required for email deliverability against the
  configured sender domain.

  Performs no network calls beyond DNS — does NOT query the Resend API or
  the Apple Developer portal (those have authoritative dashboards). The
  value is fast "is DNS correct right now" verification without bouncing
  between three tabs.

  Checks:
    * Resend SPF (TXT contains spf1 + a Resend include)
    * Resend DKIM (resend._domainkey.<domain>)
    * Resend MX (send.<domain>)
    * DMARC (_dmarc.<domain>)
    * Apple SPF include (TXT contains an apple email include)

  Usage:

      mix audit.deliverability                      # uses MAILER_FROM_EMAIL's domain
      mix audit.deliverability --domain trays.app   # override

  Exits 0 if all checks pass, 1 otherwise — CI-friendly.

  Full operator runbook: docs/email-deliverability.md
  """

  use Mix.Task

  @shortdoc "Audit DNS records for email deliverability (SPF/DKIM/DMARC/Apple)"

  @impl true
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [domain: :string])

    domain =
      Keyword.get_lazy(opts, :domain, fn ->
        case System.get_env("MAILER_FROM_EMAIL") do
          email when is_binary(email) ->
            case String.split(email, "@", parts: 2) do
              [_, d] -> d
              _ -> "trays.app"
            end

          _ ->
            "trays.app"
        end
      end)

    Mix.shell().info("Auditing deliverability for #{domain}\n")

    results = [
      check_resend_spf(domain),
      check_resend_dkim(domain),
      check_resend_mx(domain),
      check_dmarc(domain),
      check_apple_spf_include(domain)
    ]

    Enum.each(results, &print_result/1)

    passes = Enum.count(results, fn {_, _, status, _} -> status == :pass end)
    fails = length(results) - passes

    Mix.shell().info("\nSummary: #{passes} PASS, #{fails} FAIL")

    if fails > 0 do
      Mix.shell().info("\nSee docs/email-deliverability.md for remediation steps.")
      exit({:shutdown, 1})
    end
  end

  ## ---------- checks ----------

  defp check_resend_spf(domain) do
    label = "RESEND  SPF (#{domain} or send.#{domain} TXT)"

    case lookup_txt(domain) ++ lookup_txt("send.#{domain}") do
      [] ->
        {:resend_spf, label, :fail, "no TXT records returned"}

      records ->
        if Enum.any?(records, &spf_includes_resend?/1) do
          {:resend_spf, label, :pass, "SPF record includes Resend"}
        else
          {:resend_spf, label, :fail, "no SPF record includes _spf.resend.com / amazonses.com"}
        end
    end
  end

  defp check_resend_dkim(domain) do
    label = "RESEND  DKIM (resend._domainkey.#{domain})"

    case lookup_txt("resend._domainkey.#{domain}") do
      [] -> {:resend_dkim, label, :fail, "no TXT record at resend._domainkey selector"}
      records ->
        if Enum.any?(records, fn r -> String.contains?(r, "p=") end) do
          {:resend_dkim, label, :pass, "DKIM selector resolves with a public key"}
        else
          {:resend_dkim, label, :fail, "TXT exists but no p= field — record is malformed"}
        end
    end
  end

  defp check_resend_mx(domain) do
    label = "RESEND  MX (send.#{domain})"

    case lookup_mx("send.#{domain}") do
      [] -> {:resend_mx, label, :fail, "no MX records at send.<domain>"}
      _ -> {:resend_mx, label, :pass, "MX record present"}
    end
  end

  defp check_dmarc(domain) do
    label = "DMARC   _dmarc.#{domain}"

    case lookup_txt("_dmarc.#{domain}") do
      [] -> {:dmarc, label, :fail, "no TXT record at _dmarc — DMARC not published"}
      records ->
        if Enum.any?(records, fn r -> String.starts_with?(r, "v=DMARC1") end) do
          {:dmarc, label, :pass, "DMARC record published"}
        else
          {:dmarc, label, :fail, "TXT present but no v=DMARC1 prefix"}
        end
    end
  end

  defp check_apple_spf_include(domain) do
    label = "APPLE   Sign in with Apple SPF include"

    case lookup_txt(domain) ++ lookup_txt("send.#{domain}") do
      [] ->
        {:apple_spf, label, :fail, "no TXT records returned"}

      records ->
        if Enum.any?(records, &spf_includes_apple?/1) do
          {:apple_spf, label, :pass, "SPF record includes Apple email source"}
        else
          {:apple_spf, label, :fail,
           "no SPF include for Apple — Sign in with Apple users on privaterelay will not receive mail"}
        end
    end
  end

  ## ---------- helpers ----------

  defp lookup_txt(name) do
    :inet_res.lookup(to_charlist(name), :in, :txt)
    |> Enum.map(fn parts -> parts |> Enum.map(&to_string/1) |> Enum.join("") end)
  rescue
    _ -> []
  end

  defp lookup_mx(name) do
    :inet_res.lookup(to_charlist(name), :in, :mx)
  rescue
    _ -> []
  end

  defp spf_includes_resend?(record) do
    String.contains?(record, "v=spf1") and
      (String.contains?(record, "_spf.resend.com") or
         String.contains?(record, "amazonses.com"))
  end

  defp spf_includes_apple?(record) do
    String.contains?(record, "v=spf1") and
      (String.contains?(record, "_spf.email.apple.com") or
         String.contains?(record, "icloud.com"))
  end

  defp print_result({_id, label, :pass, detail}) do
    Mix.shell().info(IO.ANSI.green() <> "  PASS  " <> IO.ANSI.reset() <> label <> " — " <> detail)
  end

  defp print_result({_id, label, :fail, detail}) do
    Mix.shell().info(IO.ANSI.red() <> "  FAIL  " <> IO.ANSI.reset() <> label <> " — " <> detail)
  end
end
