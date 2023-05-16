# official Julia runtime as a parent image
FROM julia:1.8.5

# install external dependencies:
# - make & C compiler  (for building CRlibm)
# - HDF5 & SZIP & zlib  (for MAT.jl)
# - QT  (for GR.jl)
# - LaTeX & divpng  (for LaTeXStrings.jl)
RUN apt-get update && apt-get -qy install make gcc hdf5-tools libsz2 libz-dev libqt5widgets5 texlive-latex-base dvipng

# set working directory
WORKDIR /juliareach_ainncs

# copy current directory into container
COPY . /juliareach_ainncs
RUN chmod -R 777 /juliareach_ainncs

