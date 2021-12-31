defmodule Uplink.Packages.DeployTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Packages,
    Members
  }

  @deployment_params %{
    "hash" => "some-hash",
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
          "slug" => "upmaru",
          "storage" => %{
            "bucket" => "something",
            "credential" => %{
              "access_key_id" => "blah",
              "secret_access_key" => "secret"
            },
            "host" => "something.aws.com",
            "port" => 443,
            "region" => "ap-southeast-1",
            "scheme" => "https://",
            "type" => "s3"
          }
        }
      },
      "id" => 8000,
      "package" => %{"slug" => "something-1640927800"}
    }
  }

  setup do
    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    {:ok, installation} = Packages.get_or_create_installation(1)

    {:ok, deployment} =
      Packages.create_deployment(installation, @deployment_params)

    {:ok, actor: actor, deployment: deployment}
  end
end
