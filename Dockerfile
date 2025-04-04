FROM golang

RUN apt-get update && apt-get install -y graphviz npm git zip percona-toolkit
