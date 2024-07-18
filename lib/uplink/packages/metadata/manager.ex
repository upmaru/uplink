defmodule Uplink.Packages.Metadata.Manager do
  alias Uplink.Packages.Metadata
  alias Uplink.Clients.LXD

  defdelegate parse(params),
    to: Metadata

  def get_project_name(client, %Metadata{} = metadata) do
    project = project_name(metadata)

    client
    |> Lexdee.get_project(project)
    |> case do
      {:ok, %{body: %{"name" => name}}} ->
        name

      {:error, _} ->
        "default"
    end
  end

  def get_or_create_project_name(client, %Metadata{} = metadata) do
    project = project_name(metadata)

    client
    |> Lexdee.get_project(project)
    |> case do
      {:ok, %{body: %{"name" => name}}} ->
        name

      {:error, %{"error_code" => 404}} ->
        create_project(client, metadata)
    end
  end

  def get_size_profile(%Metadata{package_size: nil}), do: nil

  def get_size_profile(%Metadata{} = metadata) do
    size_profile = size_profile_name(metadata)

    LXD.client()
    |> Lexdee.get_profile(size_profile)
    |> case do
      {:ok, %{body: %{"name" => _name}}} ->
        size_profile

      {:error, %{"error_code" => 404}} ->
        nil
    end
  end

  def upsert_size_profile(%Metadata{package_size: %Metadata.Size{}} = metadata) do
    size_profile = size_profile_name(metadata)

    client = LXD.client()

    client
    |> Lexdee.get_profile(size_profile)
    |> case do
      {:ok, %{body: %{"name" => _name}}} ->
        update_size_profile(client, metadata)

      {:error, %{"error_code" => 404}} ->
        create_size_profile(client, metadata)
    end
  end

  defp create_project(client, %Metadata{} = metadata) do
    project = project_name(metadata)

    params = %{
      "config" => %{
        "features.networks" => "false",
        "features.profiles" => "false",
        "features.images" => "false",
        "features.storage.volumes" => "false"
      },
      "description" =>
        "#{metadata.channel.package.organization.slug}/#{metadata.channel.package.slug}",
      "name" => project
    }

    client
    |> Lexdee.create_project(params)
    |> case do
      {:ok, _} ->
        project

      {:error, _} ->
        nil
    end
  end

  defp create_size_profile(client, %Metadata{} = metadata) do
    profile_params = build_size_config(metadata)

    client
    |> Lexdee.create_profile(profile_params)
    |> case do
      {:ok, %{body: nil}} ->
        {:ok, :size_profile_created}

      {:error, %{"error" => message}} ->
        {:error, message}
    end
  end

  defp update_size_profile(client, %Metadata{} = metadata) do
    profile_params = build_size_config(metadata)
    profile_name = profile_params["name"]

    profile_params = Map.delete(profile_params, "name")

    client
    |> Lexdee.update_profile(profile_name, profile_params)
    |> case do
      {:ok, %{body: _body}} ->
        {:ok, :size_profile_updated}

      {:error, %{"error" => message}} ->
        {:error, message}
    end
  end

  defp build_size_config(%Metadata{package_size: package_size} = metadata) do
    profile_name = size_profile_name(metadata)

    config = %{
      "limits.cpu.allowance" => package_size.allocation.cpu_allowance,
      "limits.cpu.priority" => package_size.allocation.cpu_priority,
      "limits.memory.swap" => package_size.allocation.memory_swap,
      "limits.memory.enforce" => "#{package_size.allocation.memory_enforce}"
    }

    config =
      if package_size.allocation.cpu do
        Map.put(config, "limits.cpu", "#{package_size.allocation.cpu}")
      else
        config
      end

    config =
      if package_size.allocation.memory do
        Map.put(
          config,
          "limits.memory",
          "#{package_size.allocation.memory}#{package_size.allocation.memory_unit}"
        )
      else
        config
      end

    %{
      "name" => profile_name,
      "config" => config,
      "description" =>
        "Size profile for #{metadata.channel.package.organization.slug}/#{metadata.channel.package.slug}"
    }
  end

  defp project_name(%Metadata{channel: channel}) do
    "#{channel.package.organization.slug}.#{channel.package.slug}"
  end

  defp size_profile_name(%Metadata{channel: channel, package_size: package_size}) do
    "size.#{channel.package.organization.slug}.#{channel.package.slug}.#{package_size.slug}"
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
