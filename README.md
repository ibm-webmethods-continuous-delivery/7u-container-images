# Utilities Container Images

A collection of useful container images for the current framework.
This collection serves as a ready-to use toolset for the framework, allowing anyone having docker and preferably docker-compose installed to run the framework on their development laptop. Docker compose is thus considered a development tool, not a production deployment requirement. In productive environments, use the appropriate containerization orchestrator, such as OpenShift or Kubernetes.

Some images are also built for continuous delivery pipelines or for production use.

As a convenience, this repository is offering sandboxes grouping convenient productivity tools for building the images:

Use the sandbox `.sandbox/iwcd-ci-builder-dev` to quickly start building on your own development workstation or laptop. On the other hand, use the approach in `.sandbox/iwcd-ci-builder-cd` in the context of a continuous delivery pipeline.

## Available images

### Git guardian

Git guardian provides a single point of management when working with multiple repositories, like in our case with the framework. It aims to isolate the interactions with the git servers from the actual work on the managed repositories.
This container already provides a default toolset to work proficiently within the constraints of IBM open-source contribution rules.

### NeoVim development environments flavors

A set of containers dedicated to development, based on NeoVim for security and isolation purposes. Each flavor offers a consistent toolset for a given stack, for example developing Terraform modules for Azure, golang development, etc.

### webMethods related images

A set of images related to webMethods, like the database configuration tool, custom microservices runtimes, etc.

## Layering

The provided set of images is built with a layer strategy in mind that optimizes for the entire set size, storage and transport. The framework is not offering any container registry, the building and storage of the software falls on the responsibility of the user, who MUST ensure that all the necessary legal and compliance regulations are met.

There are three fundamental classes of layers:

- `s`: Meaning "software", this is adding software to the base images, according to need. It uses mainly the OS level package managers.
- `t`: Meaning "toolset", this is adding a set of tools to the base images, according to need. These tools are mainly scripts added by this framework.
- `u`: Meaning "user", this is adding user specific configurations to the base images, according to need. These configurations are mainly non-root configurations added on top of the other two layers.
