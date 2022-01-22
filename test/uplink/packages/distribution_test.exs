defmodule Uplink.Packages.DistributionTest do
  use ExUnit.Case, async: true

  alias Uplink.{
    Members
  }

  @app_slug "upmaru/something-1640927800"

  @deployment_params %{
    "actor" => %{
      "identifier" => "zacksiri"
    },
    "installation_id" => 1,
    "deployment" => %{
      "hash" => "some-hash",
      "archive_url" =>
        "archives/7a363fba-8ca7-4ea4-8e84-f3785ac97102/packages.zip",
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
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    {:ok, _actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    app = Packages.get_or_create_app(@app_slug)

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, @deployment_params)

    {:ok, _installation} = Packages.create_install(deployment, 1)

    {:ok, %{resource: preparing_deployment}} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    {:ok, actor: actor, deployment: preparing_deployment}
  end

  describe "matching archive node" do
    setup %{deployment: deployment, actor: actor} do
      {:ok, archive} =
        Packages.create_archive(deployment, %{
          node: "uplink@localhost",
          locations: ["#{@app_slug}/x86_64/APKINDEX.tar.gz"]
        })

      {:ok, %{resource: completed_deployment}} =
        Packages.transition_deployment_with(deployment, actor, "complete")

      {:ok, archive: archive, deployment: completed_deployment}
    end

    test "successfully fetch file" do
    end
  end
end
