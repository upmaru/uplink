defmodule Uplink.Packages.Archive.Hydrate.Schedule do
  use Oban.Worker,
    queue: :deployment,
    max_attempts: 1,
    unique: [period: 120, fields: [:worker]]

  alias Uplink.{
    Members,
    Packages,
    Repo
  }

  alias Packages.Archive

  def perform(_job) do
    bot = Members.get_bot!()

    Archive.latest_by_app_id(1)
    |> Repo.all()
    |> Enum.each(fn archive ->
      %{archive_id: archive.id, actor_id: bot.id}
      |> Archive.Hydrate.new()
      |> Oban.insert()
    end)
  end
end
