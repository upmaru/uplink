defmodule Uplink.Packages do
  alias __MODULE__.Installation

  defdelegate get_or_create_installation(instellar_installation_id),
    to: Installation.Manager,
    as: :get_or_create

  alias __MODULE__.Deployment

  defdelegate get_deployment(id),
    to: Deployment.Manager,
    as: :get

  defdelegate create_deployment(installation, params),
    to: Deployment.Manager,
    as: :create
end
