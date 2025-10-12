FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update && apt-get -y install m4 build-essential autoconf opam libunwind-dev pkg-config

USER vscode

RUN opam init -a --disable-sandboxing --yes --bare && \
        opam update -a && \
	opam switch create 5.3.0 --yes && \
	opam switch create 5.3.0+tsan ocaml-variants.5.3.0+options ocaml-option-tsan --yes && \
        opam switch create 5.2.0+ox --yes \
        --repos "ox=git+https://github.com/oxcaml/opam-repository.git,default" && \
        opam switch 5.2.0+ox

RUN opam install --switch=5.3.0 -y dune && \
	opam install --switch=5.3.0+tsan -y dune && \
	opam install -y ocamlformat merlin ocaml-lsp-server utop core await parallel && \
  opam clean -a
