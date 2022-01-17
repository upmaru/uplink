defmodule Uplink.Packages do
  alias __MODULE__.App

  defdelegate get_or_create_app(slug),
    to: App.Manager,
    as: :get_or_create

  alias __MODULE__.Archive

  defdelegate create_archive(deployment, params),
    to: Archive.Manager,
    as: :create

  alias __MODULE__.Installation

  defdelegate create_installation(deployment, instellar_installation_id),
    to: Installation.Manager,
    as: :create

  alias __MODULE__.Deployment

  defdelegate get_deployment(id),
    to: Deployment.Manager,
    as: :get

  defdelegate get_or_create_deployment(app, params),
    to: Deployment.Manager,
    as: :get_or_create

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
