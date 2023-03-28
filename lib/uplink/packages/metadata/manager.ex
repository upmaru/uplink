defmodule Uplink.Packages.Metadata.Manager do
  alias Uplink.Packages.Metadata

  defdelegate parse(params),
    to: Metadata

  def get_project_name(client, %Metadata{} = metadata) do
    client
    |> Lexdee.get_project(metadata.channel.package.slug)
    |> case do
      {:ok, %{body: %{"name" => name}}} ->
        name

      {:error, _} ->
        "default"
    end
  end

  def get_or_create_project_name(client, %Metadata{} = metadata) do
    client
    |> Lexdee.get_project(metadata.channel.package.slug)
    |> case do
      {:ok, %{body: %{"name" => name}}} ->
        name

      {:error, %{"error_code" => 404}} ->
        create_project(client, metadata)
    end
  end

  defp create_project(client, %Metadata{} = metadata) do
    params = %{
      "config" => %{
        "features.networks" => "false",
        "features.profiles" => "false",
        "features.images" => "false",
        "features.storage.volumes" => "false"
      },
      "description" => "#{metadata.channel.package.slug}",
      "name" => metadata.channel.package.slug
    }

    client
    |> Lexdee.create_project(params)
    |> case do
      {:ok, _} ->
        metadata.channel.package.slug

      {:error, _} ->
        nil
    end
  end

  def public_key_name(%Metadata{channel: channel}) do
    Enum.join([channel.package.organization.slug, channel.package.slug], "-")
  end

  def profile_name(%Metadata{id: id, channel: channel}),
    do:
      Enum.join(
        [
          channel.package.organization.slug,
          channel.package.slug,
          id
        ],
        "-"
      )
end
