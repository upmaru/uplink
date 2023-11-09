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
        create(%{slug: slug})

      %App{} = app ->
        app
    end
  end

  def create(params) do
    %App{}
    |> App.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, app} ->
        app

      {:error,
       %Ecto.Changeset{
         changes: %{slug: slug},
         errors: [
           slug: {_, [constraint: :unique, constraint_name: "apps_slug_index"]}
         ]
       }} ->
        Repo.get_by!(App, slug: slug)

      error ->
        error
    end
  end
end
