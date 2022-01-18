defmodule Uplink.Packages.Installation.ManageTest do
  use ExUnit.Case

  alias Uplink.Packages

  alias Packages.{
    Metadata,
    Installation
  }

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "metadata" => %{
      "cluster" => %{
        "credential" => %{
          "certificate" => "cert",
          "endpoint" => "https://127.0.0.1:8443",
          "password" => "somepassword",
          "password_confirmation" => "somepassword",
          "private_key" => "key"
        },
        "organization" => %{
          "slug" => "upmaru"
        }
      },
      "id" => 8000,
      "package" => %{
        "slug" => "something-1640927800",
        "organization" => %{
          "slug" => "upmaru"
        }
      }
    }
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    metadata = Map.get(@deployment_params, "metadata")

    {:ok, metadata} = Packages.parse_metadata(metadata)

    app =
      metadata
      |> Metadata.app_slug()
      |> Packages.get_or_create_app()

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, @deployment_params)

    {:ok, deployment: deployment}
  end

  describe "get_or_create" do
    alias Installation.Manager

    test "return installation", %{deployment: deployment} do
      assert {:ok, %Installation{}} = Manager.create(deployment, 1)
    end
  end
end
