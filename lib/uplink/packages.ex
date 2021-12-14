defmodule Uplink.Packages do
  defdelegate get_or_create_installation(instellar_installation_id),
    to: __MODULE__.Installation.Manager,
    as: :get_or_create

  defdelegate get_deployment(id),
    to: __MODULE__.Deployment.Manager,
    as: :get

  defdelegate create_deployment(params),
    to: __MODULE__.Deployment.Manager,
    as: :create
end
