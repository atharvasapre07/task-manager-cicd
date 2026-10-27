FROM jenkins/jenkins:lts-jdk17

USER root

# Docker CLI (talks to the host Docker through the mounted socket), Python for the tests, tools for the AWS CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends docker.io python3 python3-pip python3-venv curl unzip && \
    rm -rf /var/lib/apt/lists/*

# AWS CLI v2
RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip
