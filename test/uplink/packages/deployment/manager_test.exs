defmodule Uplink.Packages.Deployment.ManagerTest do
  use ExUnit.Case, async: true

  import Uplink.Scenarios.Deployment

  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.Deployment.Manager

  setup [:setup_endpoints, :setup_base]

  @another_deployment %{
    "hash" => "some-hash-1",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "id" => 1,
      "slug" => "uplink-web",
      "service_port" => 4000,
      "exposed_port" => 49152,
      "variables" => [
        %{"key" => "SOMETHING", "value" => "blah"}
      ],
      "channel" => %{
        "slug" => "develop",
        "package" => %{
          "slug" => "something-1640927800",
          "credential" => %{
            "public_key" => "public_key"
          },
          "organization" => %{
            "slug" => "upmaru"
          }
        }
      },
      "instances" => [
        %{
          "id" => 1,
          "slug" => "something-1",
          "node" => %{
            "slug" => "some-node"
          }
        }
      ]
    }
  }

  setup %{app: app, deployment: deployment} do
    {:ok, second_deployment} =
      Packages.get_or_create_deployment(app, @another_deployment)

    deployment
    |> Ecto.Changeset.cast(%{current_state: "live"}, [:current_state])
    |> Repo.update()

    second_deployment
    |> Ecto.Changeset.cast(%{current_state: "live"}, [:current_state])
    |> Repo.update()

    {:ok, second_deployment: second_deployment}
  end

  test "get_latest", %{
    app: app,
    second_deployment: second_deployment
  } do
    latest_deployment = Manager.get_latest(app.slug, second_deployment.channel)

    assert second_deployment.id == latest_deployment.id
  end

  test "packages get_latest_deployment", %{
    app: app,
    second_deployment: second_deployment
  } do
    latest_deployment =
      Packages.get_latest_deployment(app.slug, second_deployment.channel)

    assert second_deployment.id == latest_deployment.id
  end
end
