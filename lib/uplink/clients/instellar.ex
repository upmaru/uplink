defmodule Uplink.Clients.Instellar do
  alias Uplink.{
    Cluster
  }

  alias __MODULE__.{
    Installation,
    Deployment,
    Instance,
    Register,
    Self
  }

  @endpoint "https://web.instellar.app/uplink"

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  defdelegate get_self(),
    to: Self,
    as: :show

  defdelegate register,
    to: Register,
    as: :perform

  defdelegate restore,
    to: Self,
    as: :restore

  defdelegate deployment_metadata(install),
    to: Installation,
    as: :metadata

  defdelegate get_deployment(install),
    to: Deployment,
    as: :show

  defdelegate transition_instance(instance, install, event_name, options \\ []),
    to: Instance,
    as: :transition

  def endpoint, do: config(:endpoint) || @endpoint

  def config(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end

  def headers(hash) do
    [
      {"x-uplink-deployment-hash", hash},
      {"x-uplink-signature-256", "sha256=#{compute_signature(hash)}"},
      {"x-uplink-installation-id", Cluster.get(:installation_id)}
    ]
  end
end
