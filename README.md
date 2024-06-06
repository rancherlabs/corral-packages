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


# Using Corral Packages

## Requirements

note: it is recommended for locally running corral-packages to also have a local clone of corral, build it, and use the dev version of corral to have the latest available version. 

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


## Using Packages

### Getting Started

Once the packages are built, there will be a new directory `dist` that contains all the local corral packages. From the root of this repo, you can build a corral by specifying the local package Packages are typically from a local corral, and can be relative or absolute paths to the package. 

i.e. `dist/aws-aws-registry-standalone-rke2-rancher-airgap-calico-true-2.18.1-1.11.0/` for the airgap corral package. 

### Configure Your Corral
Once you select a package, you then need to setup corral with the variables it requires to run. You can see all the variables you'd need by looking at the packages `manifest.yaml`. Some are hardcoded, some are optional, and some are required. Currently you must look at the manifest.yaml to determine this. 

If you specify a variable in corral that is hardcoded (in the code referred to as `readonly`), corral will complain that this can't be in your config. If you are missing required variables, corral will also complain. 

Its recommended to either have a separate config to use for your corral builds, or to update your main corral config at `~/.corral/config.yaml` . The latter is recommended, as sometimes vars can be saved or left behind from previous builds that you may or may not want included in the run.

If you're having trouble on this step, you may have better luck finding an existing config in our jenkins automation in one of the recurring jobs. a

### Running Your Corral
When running locally, it is usually a good idea to enable `--skip-cleanup` and `--debug`. This will leave your corral around after it is completed (the default will cleanup everything it has created) and leave detailed logs in case anything breaks. 

That said, you should remove your setup manually after you're done using the corral with `corral delete <corral_name>`

example:

```bash
corral create <corral_name> <path_to_package> <flags>

corral create airgapExample dist/aws-aws-registry-standalone-rke2-rancher-airgap-calico-true-2.18.1-1.11.0/ --skip-cleanup --debug
```

### Using Your Corral
If you've added `skip-cleanup` flag to your create command, you likely need to grab the variables and important info from what corral built. You can view individual variables `corral vars <corral_name> <variable_name>` or view all the variables through corral `corral vars <corral_name>`. However if viewing all corral variables, I would recommend instead viewing `cat ~/.corral/corrals/<corral_name>/corral.yaml` as the output is more user-friendly. This will output every variable that corral created as part of the package. 

### Cleaning up
you can remove your setup manually after you're done QAing with `corral delete <corral_name>`
