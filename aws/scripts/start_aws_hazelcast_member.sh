#!/bin/bash
set -x

HZ_VERSION=$1
AWS_VERSION=$2

REGION=$3
TAG_KEY=$4
TAG_VALUE=$5
CONN_RETRIES=$6


HZ_JAR_URL=https://repo1.maven.org/maven2/com/hazelcast/hazelcast/${HZ_VERSION}/hazelcast-${HZ_VERSION}.jar
AWS_JAR_URL=https://repo1.maven.org/maven2/com/hazelcast/hazelcast-aws/${AWS_VERSION}/hazelcast-aws-${AWS_VERSION}.jar

mkdir -p ${HOME}/jars
mkdir -p ${HOME}/logs

pushd ${HOME}/jars
    echo "Downloading JARs..."
    if wget -q "$HZ_JAR_URL"; then
        echo "Hazelcast JAR downloaded succesfully."
    else
        echo "Hazelcast JAR could NOT be downloaded!"
        exit 1;
    fi

    if wget -q "$AWS_JAR_URL"; then
        echo "AWS Plugin JAR downloaded succesfully."
    else
        echo "AWS Plugin JAR could NOT be downloaded!"
        exit 1;
    fi
popd

sed -i -e "s/REGION/${REGION}/g" ${HOME}/hazelcast.yaml
sed -i -e "s/TAG_KEY/${TAG_KEY}/g" ${HOME}/hazelcast.yaml
sed -i -e "s/TAG_VALUE/${TAG_VALUE}/g" ${HOME}/hazelcast.yaml
sed -i -e "s/CONN_RETRIES/${CONN_RETRIES}/g" ${HOME}/hazelcast.yaml

CLASSPATH="${HOME}/jars/hazelcast-${HZ_VERSION}.jar:${HOME}/jars/hazelcast-aws-${AWS_VERSION}.jar"
nohup java -cp ${CLASSPATH} -server com.hazelcast.core.server.HazelcastMemberStarter >> ${HOME}/logs/hazelcast.stderr.log 2>> ${HOME}/logs/hazelcast.stdout.log &
sleep 5


