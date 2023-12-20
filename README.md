# ARCH2023 AINNCS

This is the JuliaReach repeatability evaluation (RE) package for the ARCH-COMP
2023 category report: Artificial Intelligence and Neural Network Control Systems
(AINNCS) for Continuous and Hybrid Systems Plants of the 7th International
Competition on Verifying Continuous and Hybrid Systems (ARCH-COMP '23).

To cite the work, you can use:

```
@inproceedings{LopezAFJLS23,
  author    = {Diego Manzanas Lopez and
               Matthias Althoff and
               Marcelo Forets and
               Taylor T.\ Johnson and
               Tobias Ladner and
               Christian Schilling},
  editor    = {Goran Frehse and
               Matthias Althoff},
  title     = {{ARCH-COMP23} Category Report: Artificial Intelligence and Neural
               Network Control Systems {(AINNCS)} for Continuous and Hybrid Systems
               Plants},
  booktitle = {{ARCH}},
  series    = {EPiC Series in Computing},
  volume    = {96},
  publisher = {EasyChair},
  year      = {2023},
  url       = {https://doi.org/10.29007/x38n},
  doi       = {10.29007/x38n}
}
```

## Installation

*Note:* Running the full benchmark suite should take no more than two hours with
a reasonable internet connection.

There are two ways to install and run this RE: either using the Julia script or
using the Docker script.
In both cases, first clone this repository.


**Using the Julia script.**
First install the Julia compiler following the instructions
[here](http://julialang.org/downloads).
Once you have installed Julia, execute

```shell
$ julia startup.jl
```

to run all the benchmarks.


**Using the Docker container.**
To build the container, you need the program `docker`.
For installation instructions on different platforms, consult
[the Docker documentation](https://docs.docker.com/install/).
For general information about `Docker`, see
[this guide](https://docs.docker.com/get-started/).
Once you have installed Docker, start the `measure_all` script:

```shell
$ ./measure_all
```

---

The Docker container can also be run interactively:

```shell
$ docker run -it juliareach bash

$ julia

julia> include("startup.jl")
```

## Outputs

After the benchmark runs have finished, the results will be stored in the folder
`result` and plots are generated in your working directory.

---

## How the Julia environment was created

```julia
julia> ]

(@v1.8) pkg> activate .
  Activating new environment at `.../ARCH2023_AINNCS/Project.toml`

pkg> add ClosedLoopReachability
pkg> add DifferentialEquations
pkg> add LinearAlgebra
pkg> add MAT
pkg> add ONNX
pkg> add Plots
pkg> add YAML
```
