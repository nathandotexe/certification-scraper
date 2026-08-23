# © AngelaMos | 2026
# storage.ex

defmodule CertScout.Storage do
  @moduledoc """
  Writes the raw artifacts to `<output>/data`: the analyzed postings (JSON + CSV),
  the certification tally (JSON + CSV), and a run summary. JSON is encoded with the
  built-in `JSON` module; CSV with NimbleCSV. Per-posting matches come straight
  from the analysis, so the matching never runs a second time here.
  """

  alias CertScout.CSV

  NimbleCSV.define(CSV, separator: ",", escape: "\"")

  @spec write(String.t(), CertScout.Analyzer.analysis(), map()) :: :ok
  def write(output_dir, analysis, meta) do
    data_dir = Path.join(output_dir, "data")
    File.mkdir_p!(data_dir)

    write_postings(data_dir, analysis, meta)
    write_certifications(data_dir, analysis, meta)
    write_summary(data_dir, analysis, meta)
    :ok
  end

  defp write_postings(dir, analysis, meta) do
    cert_names = Map.new(analysis.results, &{&1.cert.slug, &1.cert.name})
    rows = Enum.map(analysis.matched, &posting_map/1)

    File.write!(Path.join(dir, "postings.json"), JSON.encode!(rows))

    csv =
      [["Source", "Company", "Title", "Location", "URL", "Matched Certifications", "Scraped On"]]
      |> Stream.concat(
        Enum.map(rows, fn r ->
          [
            source_label(r.source),
            r.company || "Unknown",
            r.title,
            r.location || "Not specified",
            r.url || "",
            r.matched_certs |> Enum.map(&Map.get(cert_names, &1, &1)) |> Enum.join(", "),
            Date.to_iso8601(meta.generated_on)
          ]
        end)
      )
      |> CSV.dump_to_iodata()

    File.write!(Path.join(dir, "postings.csv"), csv)
  end

  defp write_certifications(dir, %{total: total, results: results}, meta) do
    ranked =
      results
      |> Enum.with_index(1)
      |> Enum.map(fn {r, rank} ->
        %{
          rank: rank,
          slug: r.cert.slug,
          name: r.cert.name,
          issuer: r.cert.issuer,
          postings: r.count,
          percent: r.percent
        }
      end)

    File.write!(Path.join(dir, "certifications.json"), JSON.encode!(%{total_cyber_postings: total, ranking: ranked}))

    csv =
      [["Rank", "Certification", "Issuer", "Postings", "Percent of Cyber Postings", "Scraped On"]]
      |> Stream.concat(
        Enum.map(ranked, fn r ->
          [r.rank, r.name, r.issuer || "Unknown", r.postings, r.percent, Date.to_iso8601(meta.generated_on)]
        end)
      )
      |> CSV.dump_to_iodata()

    File.write!(Path.join(dir, "certifications.csv"), csv)
  end

  @source_labels %{
    "workday" => "Workday",
    "greenhouse" => "Greenhouse",
    "lever" => "Lever",
    "ashby" => "Ashby",
    "remoteok" => "RemoteOK",
    "usajobs" => "USAJobs",
    "adzuna" => "Adzuna"
  }

  defp source_label(source), do: Map.get(@source_labels, source, source)

  defp write_summary(dir, %{total: total, results: results}, meta) do
    summary =
      meta
      |> Map.put(:cyber_postings, total)
      |> Map.put(
        :top,
        Enum.map(Enum.take(results, meta.top_n), &%{name: &1.cert.name, postings: &1.count, percent: &1.percent})
      )

    File.write!(Path.join(dir, "summary.json"), JSON.encode!(summary))
  end

  defp posting_map(%{posting: p, slugs: slugs}) do
    %{
      id: p.id,
      source: p.source,
      company: p.company,
      title: p.title,
      location: p.location,
      url: p.url,
      matched_certs: slugs
    }
  end
end
