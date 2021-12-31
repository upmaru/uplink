defmodule Uplink.Packages.Deployment.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Uplink.{
    Packages,
    Members
  }

  alias Packages.Deployment.Router

  @opts Router.init([])

  @valid_body Jason.encode!(%{
                "actor" => %{
                  "identifier" => "zacksiri"
                },
                "installation_id" => 1,
                "deployment" => %{
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
              })

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    {:ok, _actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    :ok
  end

  test "returns 201 for deployment creation" do
    signature =
      :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @body)
      |> Base.encode16()
      |> String.downcase()

    conn =
      conn(:post, "/", @valid_body)
      |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 201

    assert %{"data" => %{"id" => _deployment_id}} =
             Jason.decode!(conn.resp_body)
  end
end
