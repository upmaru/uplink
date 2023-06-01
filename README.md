# Uplink

![build](https://github.com/upmaru/uplink/actions/workflows/ci.yml/badge.svg)

![Uplink](cover.png)

## Why?

Uplink is designed to work with [instellar](https://github.com/upmaru/instellar). It provides protocols that enable instellar to push changes and events that propagate into dynamic configuration changes.

## Installation

You can install uplink either by using the instellar UI or Infrastructure as Code. See instructions below.
### Click Ops

You can install uplink via [instellar.app](https://instellar.app). On the cluster page. When you add a new empty cluster you can simply click on the `Setup` button.

![Setup Uplink](/public/images/setup-button.png)

Then select the option you want and simply click `Next` 

![Configure installation](/public/images/select-options.png)

### Infrastructure as Code

You can use our terraform module to install uplink on your cluster. You can create a repo from one of the templates listed here [insterra](https://github.com/orgs/insterra/repositories).

## What is Uplink?

Uplink is a module that is installed on the cluster that is being managed by [instellar.app](https://instellar.app). It provides some useful functionality such as:

- Dynamically configuring load balancing based on apps running on the cluster (Caddy)
- Container orchestration
  - Upgrading of existing apps
  - Bootstrapping new apps
- Manages state required to run applications
  - Environment variables
  - Port configurations

### How does Uplink use Caddy?

Caddy provides the heavy lifting of load balancing, routing traffic to the containers running inside the cluster and handles automatic ssl certificate issuing.

Uplink ensures that the configuration provided by the user on [instellar.app](https://instellar.app) is correctly fed into Caddy. When there is a change in configuration (i.e. new apps deployed on a cluster) uplink will automatically update caddy.

## Future Plans

Here are some features we're planning to develop for uplink.

- [x] Pro Mode - Currently the lite version is available on instellar. We want to enable pro mode to allow users to persist state to a database running outside the cluster. This will open up many more opportunities.

- [ ] Vault - Provides ability to store secrets securely on the cluster. This means all storage of environment variables will be persisted inside a cluster marked as `trusted`. Applications will directly fetch variables from uplink on the cluster without relying on [instellar.app](https://instellar.app). This will only work for uplink in `pro` mode.

- [ ] Service Discovery - Some applications need to be able to discover other instances running to be able to connect to one another. In the future uplink will provide this functionality. This will work with both `lite` and `pro` mode.


