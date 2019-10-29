<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Vineya Kubernetes](#vineya-kubernetes)
- [What is Helm?](#what-is-helm)
- [Dependencies](#dependencies)
  - [GNU Getopt](#gnu-getopt)
  - [kubectl](#kubectl)
  - [Helm](#helm)
  - [Helm-diff](#helm-diff)
- [Developer Access](#developer-access)
  - [Initial Setup](#initial-setup)
  - [Kubernetes cluster access](#kubernetes-cluster-access)
  - [Log access](#log-access)
  - [Container console access](#container-console-access)
    - [Elixir Shell Access](#elixir-shell-access)
    - [Elixir Observer Access](#elixir-observer-access)
  - [Pod Proxy Access](#pod-proxy-access)
- [Shell Completion](#shell-completion)
  - [Bash](#bash)
    - [OSX](#osx)
    - [Enabling](#enabling)
  - [Zsh](#zsh)
- [Environment Settings (Not ENV settings - settings for each environment)](#environment-settings-not-env-settings---settings-for-each-environment)
  - [Environment Hirearchy](#environment-hirearchy)
    - [Master-Ingress Hierarchy](#master-ingress-hierarchy)
    - [Vineya Hierarchy](#vineya-hierarchy)
- [Bootstrapping a New Cluster](#bootstrapping-a-new-cluster)
- [Caution: master-ingress](#caution-master-ingress)
- [Blue/Green Deploys](#bluegreen-deploys)
  - [Example](#example)
  - [Note](#note)
- [Metrics with Prometheus and Grafana](#metrics-with-prometheus-and-grafana)
  - [Updating a dashboard](#updating-a-dashboard)
- [Adding Domains](#adding-domains)
  - [Adding Blue/Green Domains](#adding-bluegreen-domains)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Vineya Kubernetes

This repository houses [Helm](https://helm.sh/) charts for running Vineya on Kubernetes

# What is Helm?

Helm is Touts itself as "The package manager for Kubernetes". It is a combination package/dependency system and a template system for Kubernetes resources.

Helm provides a simple way to install complex (multi-part) software to your Kubernetes cluster with the `helm install` command. It can be used for deploying open source software project (MySQL, Jenkins, etc. etc.) see [here](https://github.com/kubernetes/charts/tree/master/stable) for a list of stable charts.

It can also be used to build your own charts for complicated software installations. As such, Helm allows us to write templates that define the resources that are needed to run our software. Helm also allows us to separate the configuration of these templates from the templates themselves providing high-level configuration in he `env` directory.

# Dependencies

## GNU Getopt

If you are running linux, you probably already have this installed. The version of `getopt` that is shipped with OSX is not compatible with the version on GNU/Linux. You need to install the `gnu-getopt` package from Homebrew:

```
brew install gnu-getopt
```

## kubectl

On OSX kubectl can be installed with Homebrew:

```
brew install kubectl
```

## Helm

On OSX helm can be installed with Homebrew:

```
brew install kubernetes-helm
```

To being using helm it must be initialized
```
helm init -c
```

## Helm-diff

Helm-diff is a helm plugin used to show the diff between the last deployment and the changes that are about to be applied. It can be installed with:

```
helm plugin install https://github.com/databus23/helm-diff
```

Note: As of writing this there is an open issue with installing helm-diff. If the above command does not work. Check this github issue: https://github.com/databus23/helm-diff/issues/19#issuecomment-363905294

# Developer Access

## Initial Setup

Gaining access to the clusters can be done via `kops` with the `infrastructure-live` repository. This only needs to be done once per environment.

1. Login to the desired AWS account via the console - see [Accounts and Auth](https://github.com/C-S-D/infrastructure-live/blob/master/_docs/8-accounts-and-auth.md)
2. Setup a VPN connection to the desired AWS account if you haven't already - see [SSH and VPN](https://github.com/C-S-D/infrastructure-live/blob/master/_docs/7-ssh-vpn.md#vpn)
3. Enter the kops folder for the environment you wish to set up

```
cd infrastructure-live/kops/dev
```
4. Export the cluster config with `kops`

```
kops export kubecfg govineya-dev.com --state s3://govineya-dev-kops-state
```

Note: Replace `dev` with the environment you want

## Kubernetes cluster access

The kubernetes cluster can be accessed and managed by the `deploy` script in this repo or by `kubectl`.

**Before accessing the Kubernetes API, you must be connected to the VPN for the given environment you wish to manage**

## Log access

Long term logs are stored in the AWS console under Cloud Watch. Short term logs (since the last time a container started) you can use `kubectl`.

1. Make sure you have the intended environment selected (replacing govineya-dev.com with the context you want):

```
kubectl config use-context govineya-dev.com
```

2. Find the name of the pod you want access to:

```
kubectl get po
```

3. Exec a shell in the pod

```
kubectl logs -f vineya-blue-partner-server-web-5ff5ff96f8-kpxdv
```

If the pod you are trying to log has multiple containers, you may need to specify the container name too, such as:

```
kubectl logs -f vineya-blue-partner-server-web-5ff5ff96f8-kpxdv partner-server
```

Some other handy options:

* `kubectl logs --since 1h` - Will show the logs in the past hour only
* `kubectl logs -p` - Will show the logs of the previous container. This is useful if a container crashed ant you want to see the last messages before it restarted.

## Container console access

1. Make sure you have the intended environment selected (replacing govineya-dev.com with the context you want):

```
kubectl config use-context govineya-dev.com
```

2. Find the name of the pod you want access to:

```
kubectl get po
```

3. Exec a shell in the pod

```
kubectl exec -ti vineya-blue-partner-server-web-5ff5ff96f8-kpxdv bash
```

4. Load environment variables (for some reason kubernetes doesn't execute the entrypoint automatically)

```
bin/load_env bash
```

5. Go about your way

Note: When you are done, you might need to `exit` twice, once for the shell inside `load_env` once for the initial shell.

### Elixir Shell Access

If you only need to connect to _any_ elixir instance you can simply run:

```
kubectl exec -ti <interpreter-server-pod-name> -c interpreter-server -- bin/load_env iex -S mix
```

This will give you a console in a separate process to the running node that will have access to all of the same code and functions.

If you need to connect to a running BEAM instance you can do the following:

```
kubectl exec -ti <interpreter-server-pod-name> -c interpreter-server -- bin/load_env iex --name debug@127.0.0.1 --remsh interpreter@127.0.0.1 --cookie cookie-monster
```

### Elixir Observer Access

To connect to elixir's observer we need to collect a bit of information from the running pod:

```
> kubectl exec -ti <interpreter-server-pod-name> -c interpreter-server -- bin/load_env epmd -names
epmd: up and running on port <epmd-port> with data:
name interpreter at port <interpreter-port>
```

Make note of these two port numbers and setup port-forwarding:

```
kubectl port-forward <interpreter-server-pod-name> <epmd-port>:<epmd-port> <interpreter-port>:<interpreter-port>
```

Start up an observer session locally:

```
erl -name debug@127.0.0.1 -setcookie cookie-monster -hidden -run observer
```

Once observer starts go to `Nodes -> Connect Node`, enter: `interpreter@127.0.0.1` and press 'ok'. You should now see an observer instance for the running node.

## Pod Proxy Access

Some services aren't accessible through the main `http` ingress. These services are accessible through kubernetes port-forwarding. As follows:

1. Make sure you have the intended environment selected:

```
kubectl config use-context govineya-dev.com
```

2. Find the name of the pod you want access to:

```
kubectl get po
```

3. Start a port-forwarding session:

```
kubectl -n shared-services port-forward shared-services-grafana-79db48449f-nx4sp 3000:3000
```

You can now access the given service by hitting `localhost:3000` in your web browser. Note the `-n shared-services` defines a `namespace` to use, if the pod you are trying to is in the default namespace, you can omit that option.


# Shell Completion

## Bash

### OSX

OSX has bash 3 by default. For these completions to work, you need to install bash 4:

```
brew install bash
# Add the new shell to the list of allowed shells
sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
# Change to the new shell
chsh -s /usr/local/bin/bash
```

### Enabling

To add `deploy` autocompletion to your current shell, run `source <(~/path/to/deploy completion bash)`.

To add `deploy` autocompletion to your profile, so it is automatically loaded in future shells run:

```
echo "source <(~/path/to/deploy completion bash)" >> ~/.bashrc
```

## Zsh

If you are using zsh edit the `~/.zshrc` file and add the following code to enable deploy autocompletion:

```
source <(~/path/to/deploy completion zsh)
```

# Environment Settings (Not ENV settings - settings for each environment)

Settings for each environment can be found in the `env` directory. These yaml files provide values to the Helm chart templates. Most of the day-to-day changes in this repository will likely happen in the `env` directory.

## Environment Hirearchy

The environment files have a hierarchy where they override each-other before being applied to the helm templates. Mostly we will only need to adjust settings in `env/` but sometimes the settings which they override will need to be referenced.

### Master-Ingress Hierarchy

The master ingress settings are defined in the `env/[environment].master-ingress.yaml` these settings override settings in `master-ingress/values.yaml` which override the defaults in the [nginx master ingress chart](https://github.com/kubernetes/charts/blob/master/stable/nginx-ingress/values.yaml)

### Vineya Hierarchy

Vineya settings are defined in `env/[environment].[color].yaml`. This files overrides common settings in `env/[environment].common.yaml` and then defaults in `vineya/values.yaml` which overrides settings in `vineya/charts/[application]/values.yaml.

# Bootstrapping a New Cluster

Cluster bootstrapping takes a few steps:

* Enable `weave` network encryption between nodes

```
./deploy admin dev encrypt_weave
```

* Install EJSON secrets

Three Kubernetes secrets are required for the applications to run. These are the `EJSON_PRIVATE_KEY`s for each project. As these include actual secrets they are not checked in to the repository. The secrets look like this:

```
apiVersion: v1
kind: Secret
metadata:
  name: lighthouse-server
type: Opaque
data:
  EJSON_PRIVATE_KEY: <PRIVATE_KEY_BASE_64_ENCODED>
```

These secrets must be in place before proceeding to the next step. And can be installed with `kubectl apply -f partner-secret.yaml`, etc.

* Install the Certificate Manager:

```
./deploy install dev cert-manager
```

* Install the Shared Services:

```
./deploy install dev shared-services
```

* Install the Ingress Controller

```
./deploy install dev master-ingress
```

* Install the Applications

```
./deploy install dev vineya blue
```

# Caution: master-ingress

The master-ingress creates a load balancer which provides the domain name to which all of our domains are CNAME'd to. If we delete the master-ingress and re-create it it will change the domain name of the load balancer and we will have to update all of the domain names. Let's not do that.

# Blue/Green Deploys

The `master-ingress` Helm chart makes blue-green deploys possible. When you deploy an application with `./deploy [install/upgrade] [environment] blue` it names most of it's resources with `blue` in the name. The `master-ingress` also takes a color as a setting. When the chart is updated to a new color it points the `nginx` proxy to whichever colored version of the application is specified.

## Example

Let's say we are currently running on the `blue` stack. It was deployed with `./deploy install dev vineya blue`. Now we want to spin up a new version in the `green` environment.

1. Update the `env/dev.green.yaml` file with the changes for the `green` stack. (Probably image tag settings)
2. Deploy the green stack `./deploy [install|upgrade] dev vineya green`.
3. After the green services come up they should be accessible on `lighthouse.green.vineya-dev.com`
4. Once you have tested the new stack cut live traffic over to it `./deploy switch dev green`.
5. That should be it. You may want to spin down the services in the old `blue` stack at this point with `./deploy delete dev vineya blue`

## Note

By default migrations do not run when stacks are deployed. This is intentional until we get more comfortable with doing backwards compatible blue/green deployments.

Migrations can be enabled with the following settings: https://github.com/C-S-D/kubernetes/blob/master/vineya/values.yaml#L19-L22. These settings enable helm lifecycle hook jobs that will run migrations when a chart is updated/installed.

*This may not be the best way to run migrations*. Lifecycle hooks are blocking and may cause the deployment to timeout and fail. It may be better to `exec` into a container and run the migrations by hand _or_ to run a standalone kubernetes job to run the migrations.

# Metrics with Prometheus and Grafana

The cluster is instrumented with Prometheus in the shared-services chart. Grafana is used to visualize the metrics collected in Prometheus.

The dashboard can be reached at grafana.govineya-${environment}.com

To access the dashboard use the username `admin` and the randomly generated password that can be retrieved with the following command.

```
kubectl -n shared-services exec $(kubectl -n shared-services get po -l app=grafana -o jsonpath='{.items[*].metadata.name}') -c grafana env |grep PASS
```

## Updating a dashboard

You can make changes to the grafana dashboard through the UI. If you wish to persist the changes, you must save the dashboard json in `shared-services/files/k8s-dashboard.json` and update the shared-services chart. This helps keep the dashboards consistient across environments

# Adding Domains

Adding domains is a simple, but multi step process:

1. Add the new domain to the `partnerHosts` list in `env/<environment>.master-ingress.yaml`
2. Add the domain to the `dns.alpha.kubernetes.io/external` list in `env/<environment>.master-ingress.yaml`
3. Update the master-ingress: `./deploy upgrade dev master-ingress` (replace `dev` with appropriate environment as needed)

For a Production domain - you are done. For a domain that we will blue/green continue on

## Adding Blue/Green Domains

1. Make sure you have done the steps in the previous section
2. Add the domain to the `partner-server.ingress.hosts` list in `env/<environment>.common.yaml`
3. Wait a bit more for the nginx ingress to pickup new certificate secrets - maybe a minute
