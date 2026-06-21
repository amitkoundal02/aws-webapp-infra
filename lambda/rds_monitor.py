import logging
import os
from datetime import datetime, timedelta

import boto3
from botocore.exceptions import BotoCoreError, ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

FREE_STORAGE_THRESHOLD_BYTES = 5 * 1024 * 1024 * 1024  # 5 GiB


def get_env_variable(name: str) -> str:
    value = os.getenv(name)
    if not value:
        logger.error("Environment variable %s is required", name)
        raise ValueError(f"Environment variable {name} is required")
    return value


def query_free_storage_space(cw_client, db_identifier: str) -> float | None:
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=5)

    logger.info(
        "Querying FreeStorageSpace for DB instance %s from %s to %s",
        db_identifier,
        start_time.isoformat(),
        end_time.isoformat(),
    )

    response = cw_client.get_metric_statistics(
        Namespace="AWS/RDS",
        MetricName="FreeStorageSpace",
        Dimensions=[
            {"Name": "DBInstanceIdentifier", "Value": db_identifier},
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=["Average"],
        Unit="Bytes",
    )

    datapoints = response.get("Datapoints", [])
    if not datapoints:
        logger.warning("No FreeStorageSpace datapoints found for DB %s", db_identifier)
        return None

    latest = max(datapoints, key=lambda item: item["Timestamp"])
    free_storage = latest.get("Average")

    if free_storage is None:
        logger.warning("Latest FreeStorageSpace datapoint did not contain an Average value")
        return None

    logger.info(
        "Latest FreeStorageSpace for %s is %s bytes at %s",
        db_identifier,
        free_storage,
        latest["Timestamp"],
    )
    return float(free_storage)


def publish_alert(sns_client, topic_arn: str, db_identifier: str, free_storage_bytes: float) -> None:
    subject = f"RDS storage alert for {db_identifier}"
    message = (
        f"RDS DB instance {db_identifier} has low free storage space: "
        f"{free_storage_bytes:,} bytes available, below the 5 GiB threshold."
    )

    logger.info("Publishing SNS alert to %s", topic_arn)
    sns_client.publish(TopicArn=topic_arn, Subject=subject, Message=message)
    logger.info("SNS alert published for DB %s", db_identifier)


def handler(event, context):
    logger.info("Lambda handler started")

    sns_topic_arn = get_env_variable("SNS_TOPIC_ARN")
    db_identifier = get_env_variable("DB_IDENTIFIER")
    region = get_env_variable("REGION")

    cw_client = boto3.client("cloudwatch", region_name=region)
    sns_client = boto3.client("sns", region_name=region)

    try:
        free_storage = query_free_storage_space(cw_client, db_identifier)

        if free_storage is None:
            logger.info("No metric data available; skipping alert publish")
            return {
                "status": "no_data",
                "db_identifier": db_identifier,
            }

        if free_storage < FREE_STORAGE_THRESHOLD_BYTES:
            logger.warning(
                "Free storage below threshold: %s bytes < %s bytes",
                free_storage,
                FREE_STORAGE_THRESHOLD_BYTES,
            )
            publish_alert(sns_client, sns_topic_arn, db_identifier, free_storage)
            return {
                "status": "alert_sent",
                "db_identifier": db_identifier,
                "free_storage_bytes": free_storage,
            }

        logger.info(
            "Free storage is healthy: %s bytes >= %s bytes",
            free_storage,
            FREE_STORAGE_THRESHOLD_BYTES,
        )
        return {
            "status": "healthy",
            "db_identifier": db_identifier,
            "free_storage_bytes": free_storage,
        }
    except (BotoCoreError, ClientError, ValueError):
        logger.exception("Failed to evaluate RDS storage or publish alert")
        raise
