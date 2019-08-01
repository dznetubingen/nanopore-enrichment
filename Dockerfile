FROM continuumio/miniconda

RUN apt-get update && apt-get install -y procps

COPY base-env.yml /
RUN conda env create -f /base-env.yml && conda clean -a
ENV PATH /opt/conda/envs/base-env/bin:$PATH
