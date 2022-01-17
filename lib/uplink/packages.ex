defmodule Uplink.Packages do
  alias __MODULE__.Archive

  defdelegate create_archive(deployment, params),
    to: Archive.Manager,
    as: :create

  alias __MODULE__.Installation

  defdelegate get_or_create_installation(instellar_installation_id, slug),
    to: Installation.Manager,
    as: :get_or_create

  alias __MODULE__.Deployment

  defdelegate get_deployment(id),
    to: Deployment.Manager,
    as: :get

  defdelegate create_deployment(installation, params),
    to: Deployment.Manager,
    as: :create

  defdelegate transition_deployment_with(
                deployment,
                actor,
                event_name,
                opts \\ []
              ),
              to: Deployment.Manager,
              as: :transition_with

  alias __MODULE__.Metadata

  defdelegate parse_metadata(params),
    to: Metadata.Manager,
    as: :parse
end
