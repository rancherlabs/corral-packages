# Corral Packages

Corral packages is a repository of commonly used rancher setups.  These packages are intended for development and 
testing.  Corral packages should never be used for long-running or production environments.

All packages are organized by the cloud provider they are provisioned on followed by the package name.  The Package tag
will describe any relevant versions contained in the package.

# Common Variables

| Name       | Description                       |
|------------|-----------------------------------|
| kubeconfig | A base64 encoded kubeconfig file. |

## Cloud Credentials

### Digital Ocean
| Name                | Description                                                                                                               |
|---------------------|---------------------------------------------------------------------------------------------------------------------------|
| digitalocean_token  | A Digitalocean API token with write permission. https://docs.digitalocean.com/reference/api/create-personal-access-token/ |
| digitalocean_domain | The domain to use as a base for corral urls.                                                                              |

## Node Pools

Any package that creates node pools will have an `bastion` pool.  This pool contains 1 linux node that can be used
for custodial package operations.  If the package nodes have restricted access this node should be able to be used as a
jump box to all other nodes.

# Repository Structure

Templates are corral packages that can be used to generate a specific package.  They may create cloud provider infrastructure or
install kubernetes clusters on nodes.  Packages in the `templates` folder should not be rendered on their own but instead
used to compose other packages.

The `packages` directory contains manifests that compose templates and permutations of variables.  One package is created
in the dist directory for each unique permutation of the defined variables.


# Development

## Requirements

| Name   | Version   | Description                           |
|--------|-----------|---------------------------------------|
| corral | `<=1.0.0` | https://github.com/rancherlabs/corral |
| golang | `<=1.18`  | https://go.dev/doc/install            |

## Getting Started

Before you can use this repo you will need to run `make init`.

```shell
make init
```

## Building Packages

To build all the permutations of packages run `make build`.

```shell
make build
```

## Validating Packages

To validate all packages in the dist folder run `make validate`.

```shell
make validate
```