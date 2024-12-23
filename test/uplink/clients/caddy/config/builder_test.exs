defmodule Uplink.Clients.Caddy.Config.BuilderTest do
  use ExUnit.Case

  alias Uplink.Members
  alias Uplink.Packages
  alias Uplink.Secret
  alias Uplink.Cache

  alias Uplink.Packages.Metadata

  import Uplink.Scenarios.Deployment

  setup [:setup_endpoints, :setup_base]

  setup do
    Application.put_env(:uplink, Uplink.Clients.Caddy,
      storage: %{
        prefix: "uplink"
      }
    )

    :ok
  end

  test "generate caddy config", %{bypass: bypass} do
    Uplink.Cache.delete({:proxies, 1})

    System.put_env("CLOUDFLARE_DNS_TOKEN", "something")

    Bypass.expect_once(
      bypass,
      "GET",
      "/uplink/self/routers/1/proxies",
      fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{
                "attributes" => %{
                  "id" => 1,
                  "router_id" => 1,
                  "hosts" => ["opsmaru.com", "www.opsmaru.com"],
                  "paths" => ["/how-to*"],
                  "tls" => true,
                  "target" => "proxy.webflow.com",
                  "port" => 80
                }
              }
            ]
          })
        )
      end
    )

    assert %{admin: admin, apps: apps, storage: storage} =
             Uplink.Clients.Caddy.build_new_config()

    assert %{http: %{servers: %{"uplink" => server}}, tls: tls} = apps

    assert %{automation: %{policies: [policy]}} = tls

    assert %{issuers: [issuer]} = policy

    assert %{"challenges" => challenges} = issuer

    assert %{"dns" => dns, "tls-alpn" => _tls_alpn, "http" => _http} =
             challenges

    assert %{
             "provider" => %{"api_token" => "something", "name" => "cloudflare"}
           } = dns

    assert %{routes: routes} = server

    routes = Enum.sort(routes)

    [first_route, second_route, third_route] = routes

    assert %{handle: [handle], match: [match]} = first_route
    assert %{handle: [second_handle], match: [second_match]} = second_route
    assert %{handle: [third_handle], match: [third_match]} = third_route

    assert match.host == ["another.com", "something.com"]
    assert match.path == ["/configure*"]

    assert second_match.path == ["/*"]

    assert third_match.path == ["/how-to*"]

    assert "grpc.something.com" in second_match.host
    assert "grpc.another.com" in second_match.host

    [second_upstream] = second_handle.upstreams

    assert second_upstream.dial =~ "6000"

    assert %{handler: "reverse_proxy"} = handle
    assert %{host: _hosts} = match

    [third_upstream] = third_handle.upstreams

    assert %{protocol: "http", tls: %{}} = third_handle.transport

    assert third_upstream.dial == "proxy.webflow.com:80"

    assert %{identity: identity} = admin
    assert %{identifiers: ["127.0.0.1"]} = identity

    assert %{module: "s3"} = storage
  end

  describe "when routing is nil" do
    setup do
      deployment_params = %{
        "hash" => "a-different-hash",
        "archive_url" => "http://localhost/archives/packages.zip",
        "stack" => "alpine/3.14",
        "channel" => "develop",
        "metadata" => %{
          "id" => 1,
          "slug" => "uplink-web",
          "main_port" => %{
            "slug" => "web",
            "source" => 49152,
            "target" => 4000
          },
          "ports" => [
            %{
              "slug" => "grpc",
              "source" => 49153,
              "target" => 6000
            }
          ],
          "hosts" => ["something.com"],
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

      {:ok, actor} =
        Members.get_or_create_actor(%{
          "identifier" => "zacksiri",
          "provider" => "instellar",
          "id" => "1"
        })

      metadata = Map.get(deployment_params, "metadata")

      {:ok, metadata} = Packages.parse_metadata(metadata)

      app =
        metadata
        |> Metadata.app_slug()
        |> Packages.get_or_create_app()

      {:ok, deployment} =
        Packages.get_or_create_deployment(app, deployment_params)

      {:ok, %{resource: preparing_deployment}} =
        Packages.transition_deployment_with(deployment, actor, "prepare")

      {:ok, %{resource: deployment}} =
        Packages.transition_deployment_with(
          preparing_deployment,
          actor,
          "complete"
        )

      {:ok, install} =
        Packages.create_install(deployment, %{
          "installation_id" => 1,
          "deployment" => deployment_params
        })

      signature = Secret.Signature.compute_signature(deployment.hash)

      Cache.put(
        {:deployment, signature, install.instellar_installation_id},
        metadata
      )

      {:ok, %{resource: validating_install}} =
        Packages.transition_install_with(install, actor, "validate")

      {:ok, %{resource: _executing_install}} =
        Packages.transition_install_with(validating_install, actor, "execute")

      :ok
    end

    test "render port when routing is nil correctly" do
      assert %{apps: apps} = Uplink.Clients.Caddy.build_new_config()

      assert %{http: %{servers: %{"uplink" => server}}} = apps

      assert %{routes: routes} = server

      routes = Enum.sort(routes)

      [first_route, second_route] = routes

      assert %{handle: [handle], match: [match]} = first_route
      assert %{handle: [second_handle], match: [second_match]} = second_route

      assert match.host == ["something.com"]
      assert match.path == ["*"]

      assert second_match.path == ["*"]

      assert "grpc.something.com" in second_match.host

      [second_upstream] = second_handle.upstreams

      assert second_upstream.dial =~ "6000"

      assert %{handler: "reverse_proxy"} = handle
      assert %{host: _hosts} = match
    end
  end
end
