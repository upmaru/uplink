defmodule Uplink.Packages.Deployment.PrepareTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Packages,
    Members
  }

  alias Packages.Deployment.{
    Prepare
  }

  @deployment_params %{
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
      "package" => %{"slug" => "something-1640927800"}
    }
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)
    
    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    {:ok, installation} = Packages.get_or_create_installation(1)

    {:ok, deployment} =
      Packages.create_deployment(installation, @deployment_params)

    {:ok, _transition} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    {:ok, actor: actor, deployment: deployment}
  end

  test "successfully prepare deployment", %{
    deployment: deployment,
    actor: actor
  } do
    assert {:ok, _transition} =
             perform_job(Prepare, %{
               deployment_id: deployment.id,
               actor_id: actor.id
             })
  end
end
