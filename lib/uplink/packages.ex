defmodule Uplink.Packages do
  alias __MODULE__.App

  defdelegate get_or_create_app(slug),
    to: App.Manager,
    as: :get_or_create

  alias __MODULE__.Archive

  defdelegate create_archive(deployment, params),
    to: Archive.Manager,
    as: :create

  defdelegate update_archive(archive, params),
    to: Archive.Manager,
    as: :update

  alias __MODULE__.Install

  defdelegate install_cache_key(install),
    to: Install.Manager,
    as: :cache_key

  defdelegate build_install_state(install, actor \\ nil),
    to: Install.Manager,
    as: :build_state

  defdelegate latest_install(instellar_installation_id),
    to: Install.Manager,
    as: :latest

  defdelegate create_install(deployment, params),
    to: Install.Manager,
    as: :create

  defdelegate transition_install_with(install, actor, event_name, opts \\ []),
    to: Install.Manager,
    as: :transition_with

  defdelegate maybe_mark_install_complete(install, actor),
    to: Install.Manager,
    as: :maybe_mark_complete

  alias __MODULE__.Deployment

  defdelegate get_deployment(id),
    to: Deployment.Manager,
    as: :get

  defdelegate get_latest_deployment(slug, channel),
    to: Deployment.Manager,
    as: :get_latest

  defdelegate get_or_create_deployment(app, params),
    to: Deployment.Manager,
    as: :get_or_create

  defdelegate update_deployment(deployment, params),
    to: Deployment.Manager,
    as: :update

  defdelegate transition_deployment_with(
                deployment,
                actor,
                event_name,
                opts \\ []
              ),
              to: Deployment.Manager,
              as: :transition_with

  alias __MODULE__.Metadata

  defdelegate get_project_name(client, metadata),
    to: Metadata.Manager

  defdelegate get_or_create_project_name(client, metadata),
    to: Metadata.Manager

  defdelegate get_or_create_size_profile(cient, metadata),
    to: Metadata.Manager

  defdelegate profile_name(metadata),
    to: Metadata.Manager

  defdelegate public_key_name(metadata),
    to: Metadata.Manager

  defdelegate parse_metadata(params),
    to: Metadata.Manager,
    as: :parse

  alias __MODULE__.Distribution

  defdelegate distribution_url(metadata),
    to: Distribution.Manager,
    as: :url
end
