FROM amazonlinux:2

RUN yum update -y && \
    yum install -y python3 python3-pip && \
    yum clean all

RUN pip3 install boto3 requests

COPY pipeline_trigger.py /app/pipeline_trigger.py
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]
