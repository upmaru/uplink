defmodule Uplink.Caddy.Config.Upstreams do
  alias Uplink.Cache
  alias Uplink.Packages.Metadata
  alias Uplink.Packages.Metadata.Port

  def build(%Metadata{instances: instances}, %Port{} = port, install_id) do
    instances
    |> filter_valid(install_id)
    |> Enum.map(fn instance ->
      %{
        dial: "#{instance.slug}:#{port.target}",
        max_requests: 100
      }
    end)
  end

  def filter_valid(instances, install_id) do
    completed_instances = Cache.get({:install, install_id, "completed"})

    if is_list(completed_instances) and Enum.count(completed_instances) > 0 do
      instances
      |> Enum.filter(fn instance ->
        instance.slug in completed_instances
      end)
    else
      instances
    end
  end
end
