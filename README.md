# Uplink

![build](https://github.com/upmaru/uplink/actions/workflows/ci.yml/badge.svg)

![Uplink](cover.png)

## Installation

You can install uplink via [instellar.app](https://instellar.app). On the cluster page. When you add a new empty cluster you can simply click on the `Setup` button.

![Setup Uplink](/public/images/setup-button.png)

Then select the option you want and simply click `Next` 

![Configure installation](/public/images/select-options.png)

## What is Uplink?

Uplink is a module that is installed on the cluster that is being managed by [instellar.app](https://instellar.app). It provides some useful functionality such as:

- Configure load balancing based on apps running on the cluster (Caddy)
- Container orchestration
  - Upgrading of existing apps
  - Bootstrapping new apps
- Manages state required to run applications
  - Environment variables
  - Port configurations

### How does Uplink use Caddy?

Caddy provides the heavy lifting of load balancing, routing traffic to the containers running inside the cluster and handles automatic ssl certificate issuing.

Uplink ensures that the configuration provided by the user on [instellar.app](https://instellar.app) is correctly fed into Caddy.

## Future Plans

Here are some features we're planning to develop for uplink.

- [ ] Pro Mode - Currently the lite version is available on instellar. We want to enable pro mode to allow users to persist state to a database not running on the cluster. This will open up many more opportunities.

- [ ] Vault - Provides ability to store secrets securely on the cluster. This means all storage of environment variables will be persisted inside a cluster marked as `trusted`. Applications will directly fetch variables from uplink on the cluster without relying on [instellar.app](https://instellar.app). This will only work for uplink in `pro` mode.

- [ ] Service Discovery - Some applications need to be able to discover other instances running to be able to connect to one another. In the future uplink will provide this functionality.


