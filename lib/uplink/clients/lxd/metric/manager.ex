defmodule Uplink.Clients.LXD.Metric.Manager do
  alias Uplink.Clients.LXD

  def list(_options \\ []) do
    LXD.client()
    |> Lexdee.list_metrics()
    |> case do
      {:ok, %{body: raw_metrics}} ->
        raw_metrics
        |> String.split("\n")
        |> Enum.map(fn line ->
          PrometheusParser.parse(line)
        end)
        |> Enum.map(fn
          {:ok, line} -> line
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(fn line ->
          line.line_type != "ENTRY"
        end)

      error ->
        error
    end
  end
end
