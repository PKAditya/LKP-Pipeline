# LKP-Pipeline
## Getting Started
  LKP-Pipeline is designed to help kernel developers with the checks of regression with various test-suites. To start with the run, follow the below steps.

```

        # clone the repository
        git clone https://github.com/PKAditya/LKP-Pipeline.git

        cd LKP-Pipeline
        ./run.sh

```

The user needs to provide input required for setting up the system. Required inputs are listed out below

1. Path to the kernel git repository
2. Branch of the kernel repository
3. Base commit of the kernel repository, before applying the patches
4. Name of the vm without lkp installed as service on it
5. Name of the vm with lkp installed as service on it
6. Number of required non-lkp vms required (Note that the number of vms could vary depending on the specs of your host system)
7. Number of required lkp vms required (Note that the number of vms could vary depending on the specs of your host system)

## Supported Distributions
Present version of code only support the below listed distros:

Debian Based:

- Ubuntu
- VELinux

RHEL based:

- Centos
- Opencloudos
- OpenEuler
- OpenAnolis
