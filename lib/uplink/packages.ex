defmodule Uplink.Packages do
  alias __MODULE__.App

  defdelegate get_or_create_app(slug),
    to: App.Manager,
    as: :get_or_create

  alias __MODULE__.Archive

  defdelegate create_archive(deployment, params),
    to: Archive.Manager,
    as: :create

  alias __MODULE__.Install

  defdelegate build_install_state(install, actor),
    to: Install.Manager,
    as: :build_state

  defdelegate create_install(deployment, instellar_installation_id),
    to: Install.Manager,
    as: :create

  defdelegate transition_install_with(install, actor, event_name, opts \\ []),
    to: Install.Manager,
    as: :transition_with

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

  defdelegate profile_name(metadata),
    to: Metadata.Manager

  defdelegate parse_metadata(params),
    to: Metadata.Manager,
    as: :parse

  alias __MODULE__.Distribution

  defdelegate distribution_url(metadata),
    to: Distribution.Manager,
    as: :url
end
