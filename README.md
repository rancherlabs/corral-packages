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
