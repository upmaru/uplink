defmodule Uplink.Packages.Deployment.RouterTest do
  use ExUnit.Case
  use Plug.Test

  alias Uplink.{
    Repo,
    Packages,
    Members
  }

  alias Packages.Deployment.Router

  @opts Router.init([])

  @app_slug "upmaru/something-1640927800"

  @valid_body Jason.encode!(%{
                "actor" => %{
                  "provider" => "instellar",
                  "identifier" => "zacksiri",
                  "id" => "1"
                },
                "installation_id" => 1,
                "deployment" => %{
                  "hash" => "some-hash",
                  "stack" => "alpine/3.14",
                  "channel" => "develop",
                  "archive_url" =>
                    "archives/7a363fba-8ca7-4ea4-8e84-f3785ac97102/packages.zip",
                  "metadata" => %{
                    "id" => 3,
                    "slug" => "uplink-web",
                    "service_port" => 4000,
                    "exposed_port" => 49152,
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
              })

  @invalid_body Jason.encode!(%{
                  "actor" => %{
                    "identifier" => "zacksiri"
                  },
                  "installation_id" => 1,
                  "deployment" => %{
                    "hash" => "some-hash",
                    "archive_path" =>
                      "archives/7a363fba-8ca7-4ea4-8e84-f3785ac97102/packages.zip",
                    "metadata" => %{}
                  }
                })

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    :ok
  end

  describe "create deployment" do
    test "returns 201 for deployment creation" do
      tasks =
        1..2
        |> Enum.to_list()
        |> Enum.map(fn n ->
          Task.async(fn ->
            body =
              Jason.decode!(@valid_body)
              |> Map.merge(%{"installation_id" => n})
              |> Jason.encode!()

            signature =
              :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), body)
              |> Base.encode16()
              |> String.downcase()

            conn =
              conn(:post, "/", body)
              |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
              |> put_req_header("content-type", "application/json")
              |> Router.call(@opts)

            %{conn: conn, index: n}
          end)
        end)

      tasks_with_results = Task.yield_many(tasks)

      Enum.each(tasks_with_results, fn {_task, result} ->
        {:ok, %{conn: conn, index: _index}} = result

        assert conn.status == 201

        assert %{"data" => %{"id" => deployment_id}} =
                 Jason.decode!(conn.resp_body)

        deployment = Uplink.Repo.get(Uplink.Packages.Deployment, deployment_id)

        assert deployment.current_state == "preparing"
      end)
    end
  end

  describe "repeated deployment push" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      conn(:post, "/", @valid_body)
      |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

      {:ok, signature: signature}
    end

    test "return 422 for repeated push", %{signature: signature} do
      conn =
        conn(:post, "/", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 422

      assert %{
               "data" => %{
                 "errors" => %{"deployment_id" => ["has already been taken"]}
               }
             } = Jason.decode!(conn.resp_body)
    end
  end

  describe "repeated deployment push with different installation_id" do
    setup do
      original_signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(:post, "/", @valid_body)
        |> put_req_header(
          "x-uplink-signature-256",
          "sha256=#{original_signature}"
        )
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      %{"data" => %{"id" => deployment_id}} = Jason.decode!(conn.resp_body)

      deployment = Uplink.Repo.get(Uplink.Packages.Deployment, deployment_id)

      {:ok, _deployment} =
        deployment
        |> Ecto.Changeset.cast(%{current_state: "live"}, [:current_state])
        |> Repo.update()

      body =
        Jason.decode!(@valid_body)
        |> Map.merge(%{"installation_id" => 2})
        |> Jason.encode!()

      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, body: body, signature: signature}
    end

    test "returns 201 for creating install", %{body: body, signature: signature} do
      conn =
        conn(:post, "/", body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201

      assert %{
               "data" => %{
                 "id" => deployment_id,
                 "install" => %{"id" => install_id}
               }
             } = Jason.decode!(conn.resp_body)

      deployment = Uplink.Repo.get(Uplink.Packages.Deployment, deployment_id)

      assert deployment.current_state == "live"

      install = Uplink.Repo.get(Uplink.Packages.Install, install_id)

      assert install.current_state == "validating"
    end
  end

  describe "invalid body" do
    test "returns 422 for deployment creation" do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @invalid_body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(:post, "/", @invalid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 422

      assert %{"data" => %{"errors" => _errors}} = Jason.decode!(conn.resp_body)
    end
  end

  @uplink_installation_state_response %{
    "data" => %{
      "attributes" => %{
        "id" => 1,
        "slug" => "uplink-web",
        "main_port" => %{
          "slug" => "web",
          "source" => 49142,
          "target" => 4000
        },
        "variables" => [
          %{"key" => "SOMETHING", "value" => "somevalue"}
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
  }

  describe "create install event" do
    setup do
      bypass = Bypass.open()

      Application.put_env(
        :uplink,
        Uplink.Clients.Instellar,
        endpoint: "http://localhost:#{bypass.port}/uplink"
      )

      params = Jason.decode!(@valid_body)

      {:ok, actor} = Members.get_or_create_actor(Map.get(params, "actor"))

      deployment_params = Map.get(params, "deployment")

      {:ok, metadata} = Packages.parse_metadata(deployment_params["metadata"])

      app = Packages.get_or_create_app(@app_slug)

      {:ok, deployment} =
        Packages.get_or_create_deployment(app, deployment_params)

      {:ok, install} =
        Packages.create_install(deployment, %{
          "installation_id" => metadata.id,
          "deployment" => deployment_params
        })

      {:ok, %{resource: validating_install}} =
        Packages.transition_install_with(install, actor, "validate")

      body =
        Jason.encode!(%{
          "actor" => %{
            "identifier" => "zacksiri",
            "provider" => "instellar",
            "id" => "1"
          },
          "event" => %{
            "name" => "complete",
            "comment" => "installation synced successful"
          }
        })

      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), body)
        |> Base.encode16()
        |> String.downcase()

      {:ok,
       body: body,
       actor: actor,
       install: validating_install,
       signature: signature,
       deployment: deployment,
       bypass: bypass,
       metadata: metadata}
    end

    test "when install doesn't exist", %{
      body: body,
      deployment: deployment,
      signature: signature
    } do
      conn =
        conn(:post, "/#{deployment.hash}/installs/234/events", body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 404
    end

    test "can mark install complete", %{
      body: body,
      actor: actor,
      deployment: deployment,
      install: install,
      signature: signature,
      metadata: metadata
    } do
      {:ok, %{resource: _executing_install}} =
        Packages.transition_install_with(install, actor, "execute")

      conn =
        conn(:post, "/#{deployment.hash}/installs/#{metadata.id}/events", body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201
      assert %{"data" => data} = Jason.decode!(conn.resp_body)
      assert %{"id" => _id, "name" => "complete"} = data
    end

    test "can refresh metadata for given deployment", %{
      deployment: deployment,
      metadata: metadata,
      bypass: bypass
    } do
      Bypass.expect_once(bypass, "GET", "/uplink/installations/3", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(@uplink_installation_state_response)
        )
      end)

      body =
        Jason.encode!(%{
          "event" => %{
            "name" => "refresh"
          }
        })

      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(
          :post,
          "/#{deployment.hash}/installs/#{metadata.id}/metadata/events",
          body
        )
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 200
    end

    test "can refresh metadata for given deployment when install doesn't exist",
         %{
           deployment: deployment
         } do
      body =
        Jason.encode!(%{
          "event" => %{
            "name" => "refresh"
          }
        })

      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(
          :post,
          "/#{deployment.hash}/installs/36/metadata/events",
          body
        )
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 404
    end

    test "can delete metadata for a given deployment", %{
      deployment: deployment,
      metadata: metadata
    } do
      body =
        Jason.encode!(%{
          "event" => %{
            "name" => "delete"
          }
        })

      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(
          :post,
          "/#{deployment.hash}/installs/#{metadata.id}/metadata/events",
          body
        )
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 200
    end

    test "return 422 when invalid state", %{
      body: body,
      deployment: deployment,
      signature: signature,
      metadata: metadata
    } do
      conn =
        conn(:post, "/#{deployment.hash}/installs/#{metadata.id}/events", body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 422
      assert %{"data" => _data} = Jason.decode!(conn.resp_body)
    end
  end
end
