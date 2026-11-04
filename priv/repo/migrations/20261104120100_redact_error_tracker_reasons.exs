defmodule TraysSocial.Repo.Migrations.RedactErrorTrackerReasons do
  use Ecto.Migration

  # D120: ErrorTracker hands its filter only the context, never the exception
  # message it stores as `reason` on both tables, and messages such as KeyError
  # and MatchError print the map they failed on (a login form's password). This
  # BEFORE INSERT/UPDATE trigger rewrites `reason` before the row is written,
  # so the plaintext is never committed. `TraysSocial.ErrorReports.scrub/1`
  # re-fires it on existing rows by setting reason = reason.
  #
  # It replaces, case-insensitively:
  #   * the quoted value of an inspected pair whose key looks sensitive:
  #     "password" => "x", password: "x", :api_key => "x"
  #   * a Bearer/Basic credential
  #   * any email address
  def up do
    execute ~S"""
    CREATE OR REPLACE FUNCTION trays_redact_error_reason() RETURNS trigger AS $$
    BEGIN
      IF NEW.reason IS NOT NULL THEN
        NEW.reason := regexp_replace(
          NEW.reason,
          '((?:"|:)?[A-Za-z0-9_-]*(?:password|token|secret|jws|signed|authorization|cookie|email|recipient|api_?key)[A-Za-z0-9_-]*"?:?\s*(?:=>\s*)?)"(?:[^"\\]|\\.)*"',
          '\1"[REDACTED]"',
          'gi'
        );
        NEW.reason := regexp_replace(NEW.reason, '\m(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+', '\1 [REDACTED]', 'gi');
        NEW.reason := regexp_replace(NEW.reason, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[REDACTED]', 'g');
      END IF;
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql
    """

    for table <- ~w(error_tracker_occurrences error_tracker_errors) do
      execute """
      CREATE TRIGGER #{table}_redact_reason
      BEFORE INSERT OR UPDATE OF reason ON #{table}
      FOR EACH ROW EXECUTE FUNCTION trays_redact_error_reason()
      """
    end
  end

  def down do
    for table <- ~w(error_tracker_occurrences error_tracker_errors) do
      execute "DROP TRIGGER IF EXISTS #{table}_redact_reason ON #{table}"
    end

    execute "DROP FUNCTION IF EXISTS trays_redact_error_reason()"
  end
end
