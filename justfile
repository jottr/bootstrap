# Dev command surface. Container work lives in the `container` module,
# invoked as `just container <recipe>`.

mod container

default:
    @just --list
