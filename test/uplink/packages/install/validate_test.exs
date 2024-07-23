defmodule Uplink.Packages.Install.ValidateTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Packages,
    Members,
    Cache
  }

  alias Packages.{
    Metadata,
    Install
  }

  alias Install.Validate

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "id" => 1,
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

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Cache.delete(:profiles)

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    {:ok, actor} =
      Members.get_or_create_actor(%{
        "identifier" => "zacksiri",
        "provider" => "instellar",
        "id" => "1"
      })

    metadata = Map.get(@deployment_params, "metadata")

    {:ok, metadata} = Packages.parse_metadata(metadata)

    list_profiles = File.read!("test/fixtures/lxd/profiles/list.json")

    app =
      metadata
      |> Metadata.app_slug()
      |> Packages.get_or_create_app()

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, @deployment_params)

    {:ok, install} =
      Packages.create_install(deployment, %{
        "installation_id" => 1,
        "deployment" => @deployment_params
      })

    signature = compute_signature(deployment.hash)

    Cache.put(
      {:deployment, signature, install.instellar_installation_id},
      metadata
    )

    {:ok, %{resource: validating_install}} =
      Packages.transition_install_with(install, actor, "validate")

    {:ok,
     install: validating_install,
     deployment: deployment,
     metadata: metadata,
     actor: actor,
     bypass: bypass,
     list_profiles: list_profiles}
  end

  describe "when profile does not exist" do
    setup do
      Cache.put(:instances, [])

      create_profile = File.read!("test/fixtures/lxd/profiles/create.json")

      {:ok, create_profile: create_profile}
    end

    test "invokes create profile", %{
      bypass: bypass,
      install: install,
      actor: actor,
      list_profiles: list_profiles,
      create_profile: create_profile
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/profiles", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, list_profiles)
      end)

      Bypass.expect_once(bypass, "POST", "/1.0/profiles", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, create_profile)
      end)

      assert {:ok, %{resource: install}} =
               perform_job(Validate, %{
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert install.current_state == "executing"
    end
  end

  describe "when profile exists" do
    setup do
      list_profiles =
        File.read!("test/fixtures/lxd/profiles/list_profile_exists.json")

      update_profile = File.read!("test/fixtures/lxd/profiles/update.json")

      {:ok, list_profiles: list_profiles, update_profile: update_profile}
    end

    test "transition install to execute", %{
      bypass: bypass,
      install: install,
      actor: actor,
      metadata: metadata,
      list_profiles: list_profiles,
      update_profile: update_profile
    } do
      profile_name = Packages.profile_name(metadata)

      Bypass.expect_once(bypass, "GET", "/1.0/profiles", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, list_profiles)
      end)

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/1.0/profiles/#{profile_name}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, update_profile)
        end
      )

      assert {:ok, %{resource: install}} =
               perform_job(Validate, %{
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert install.current_state == "executing"
    end
  end

  @deployment_params_with_package_size %{
    "hash" => "some-hash-with-package-size",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "id" => 1,
      "slug" => "uplink-web",
      "service_port" => 4000,
      "exposed_port" => 49152,
      "package_size" => %{
        "slug" => "medium",
        "allocation" => %{
          "cpu" => 1,
          "cpu_allowance" => "100%",
          "cpu_priority" => 10,
          "memory" => 1,
          "memory_unit" => "GiB",
          "memory_swap" => false,
          "memory_enforce" => "hard"
        }
      },
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

  describe "with package size" do
    setup %{actor: actor} do
      create_profile = File.read!("test/fixtures/lxd/profiles/create.json")

      metadata = Map.get(@deployment_params_with_package_size, "metadata")

      {:ok, metadata} = Packages.parse_metadata(metadata)

      app =
        metadata
        |> Metadata.app_slug()
        |> Packages.get_or_create_app()

      {:ok, deployment} =
        Packages.get_or_create_deployment(
          app,
          @deployment_params_with_package_size
        )

      {:ok, install} =
        Packages.create_install(deployment, %{
          "installation_id" => 1,
          "deployment" => @deployment_params_with_package_size
        })

      signature = compute_signature(deployment.hash)

      Cache.put(
        {:deployment, signature, install.instellar_installation_id},
        metadata
      )

      {:ok, %{resource: validating_install}} =
        Packages.transition_install_with(install, actor, "validate")

      size_profile =
        "size.#{metadata.channel.package.organization.slug}.#{metadata.channel.package.slug}.#{validating_install.metadata_snapshot.package_size.slug}"

      {:ok,
       install: validating_install,
       deployment: deployment,
       metadata: metadata,
       create_profile: create_profile,
       size_profile: size_profile}
    end

    test "can create app profile and size profile", %{
      bypass: bypass,
      install: install,
      actor: actor,
      list_profiles: list_profiles,
      size_profile: size_profile
    } do
      size_profile_not_found =
        File.read!("test/fixtures/lxd/profiles/not_found.json")

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/profiles/#{size_profile}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, size_profile_not_found)
        end
      )

      create_profile = File.read!("test/fixtures/lxd/profiles/create.json")

      Bypass.expect(
        bypass,
        "POST",
        "/1.0/profiles",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, create_profile)
        end
      )

      Bypass.expect_once(bypass, "GET", "/1.0/profiles", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, list_profiles)
      end)

      assert {:ok, %{resource: install}} =
               perform_job(Validate, %{
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert install.current_state == "executing"
    end

    test "can update app profile and size profile", %{
      bypass: bypass,
      install: install,
      metadata: metadata,
      actor: actor,
      size_profile: size_profile
    } do
      list_profiles =
        File.read!("test/fixtures/lxd/profiles/list_profile_exists.json")

      update_profile = File.read!("test/fixtures/lxd/profiles/update.json")

      profile_name = Packages.profile_name(metadata)

      Bypass.expect_once(bypass, "GET", "/1.0/profiles", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, list_profiles)
      end)

      size_profile_response =
        File.read!("test/fixtures/lxd/profiles/show_size_profile.json")

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/profiles/#{size_profile}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, size_profile_response)
        end
      )

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/1.0/profiles/#{profile_name}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, update_profile)
        end
      )

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/1.0/profiles/#{size_profile}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, update_profile)
        end
      )

      assert {:ok, %{resource: install}} =
               perform_job(Validate, %{
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert install.current_state == "executing"
    end
  end
end
