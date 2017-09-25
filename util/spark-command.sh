#!/usr/bin/env bash

if [ $# -ne 4 ]; then
    echo "Spark shell needs 4 parameters: {keytabLocalPath} {keytabUsername} {realm} {sparkCommand}"
    exit 1
fi

echo `hostname`
# With CDH Spark 2.2, there seems to have been a regression with SPARK-19995 that
# would cause the following problem:
#
# "Delegation Token can be issued only with kerberos or web authentication"
#
# In order to workaround that error, we are unsetting the following parameter
# which seems to be getting read in by spark2-submit command causing us to fail.
#
# It *may* cause other unknown side-effects in which case, resorting to SSH-ing
# to another node and run the spark2-submit through a script OR using SSH action
# in Oozie may be the only way for now.
echo "Current HADOOP_TOKEN_FILE_LOCATION: ${HADOOP_TOKEN_FILE_LOCATION}"
echo "Unsetting HADOOP_TOKEN_FILE_LOCATION"
unset HADOOP_TOKEN_FILE_LOCATION

# Get the keytab
echo "Initializing kerberos"
uniqCacheFile=/tmp/krb5cc_spark_kafka_${2}
echo "Unique cache file: ${uniqCacheFile}"
kinit -k -c ${uniqCacheFile} -t ${1} ${2}@${3}
if [ $? -ne 0 ]; then
    echo "Could not perform a kinit, failing the job"
    exit 1
fi
export KRB5CCNAME=${uniqCacheFile}
klist -ef

#echo "Passing following command to spark: ${4}"
echo "Executing spark submit"
#${4}
SPARK_KAFKA_VERSION=0.10 spark2-submit --conf spark.yarn.queue=root.low --num-executors 2 --master yarn --deploy-mode client --files spark_jaas.conf#spark_jaas.conf,user.keytab#user.keytab --driver-java-options "-Djava.security.auth.login.config=./spark_jaas.conf" --class com.cloudera.spark.examples.KafkaEventConsumer --conf "spark.executor.extraJavaOptions=-Djava.security.auth.login.config=./spark_jaas.conf" spark-secure-kafka-app-1.0-SNAPSHOT-jar-with-dependencies.jar cdh-kafka.acme.com:9093 mladen_apachelogs cgroup_mladen_apachelogs true /opt/cloudera/security/jks/truststore.jks password
