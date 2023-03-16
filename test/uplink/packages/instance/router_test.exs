defmodule Uplink.Packages.Instance.RouterTest do
  use ExUnit.Case
  use Plug.Test

  @app_slug "upmaru/something-1640927800"

  alias Uplink.{
    Members,
    Packages
  }

  alias Packages.Instance.Router

  @opts Router.init([])

  @valid_body Jason.encode!(%{
                "actor" => %{
                  "provider" => "instellar",
                  "identifier" => "zacksiri",
                  "id" => "1"
                },
                "installation_id" => 1,
                "instance" => %{
                  "slug" => "some-instane-1",
                  "node" => %{
                    "slug" => "some-node-1"
                  }
                }
              })

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost:4000/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "installation" => %{
        "id" => 1,
        "slug" => "uplink-web",
        "service_port" => 4000,
        "exposed_port" => 49152,
        "instances" => [
          %{
            "installation_instance_id" => 1,
            "slug" => "something-1"
          }
        ]
      },
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

    {:ok, actor} =
      Members.get_or_create_actor(%{
        "identifier" => "zacksiri",
        "provider" => "instellar",
        "id" => "1"
      })

    app = Packages.get_or_create_app(@app_slug)

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, @deployment_params)

    {:ok, %{resource: deployment}} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    {:ok, _transition} =
      Packages.transition_deployment_with(deployment, actor, "complete")

    {:ok, _install} = Packages.create_install(deployment, 1)

    :ok
  end

  describe "successfully schedule bootstrap instance" do
    test "returns 201 for instance bootstrap" do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(:post, "/bootstrap", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201

      assert %{"data" => %{"id" => _job_id}} = Jason.decode!(conn.resp_body)
    end

    test "returns 201 for instance cleanup" do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(:post, "/cleanup", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201

      assert %{"data" => %{"id" => _job_id}} = Jason.decode!(conn.resp_body)
    end

    test "returns 201 for instance upgrade" do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(:post, "/upgrade", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201

      assert %{"data" => %{"id" => _job_id}} = Jason.decode!(conn.resp_body)
    end

    test "return unauthorized when request sent without signature" do
      conn =
        conn(:post, "/bootstrap", @valid_body)
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 401
    end
  end
end
