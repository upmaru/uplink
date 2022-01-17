defmodule Uplink.Packages.App.Manager do
  alias Uplink.{
    Repo,
    Packages
  }

  alias Packages.App

  def get_or_create(slug) do
    App
    |> Repo.get_by(slug: slug)
    |> case do
      nil ->
        %App{}
        |> App.changeset(%{slug: slug})
        |> Repo.insert!()

      %App{} = app ->
        app
    end
  end
end
