defmodule Uplink.Packages.Install.Execute do
  use Oban.Worker, queue: :execute_install, max_attempts: 1

  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.Install

  import Ecto.Query,
    only: [where: 3]

  def perform(%Oban.Job{args: %{"install_id" => install_id}}) do
    install =
      Install
      |> where([i], i.current_state == ^"executing")
      |> Repo.get(install_id)
  end
end
