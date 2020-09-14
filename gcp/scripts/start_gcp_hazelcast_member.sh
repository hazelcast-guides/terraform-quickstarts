#!/bin/bash
set -x

HZ_VERSION=$1
GCP_VERSION=$2
LABEL_KEY=$3
LABEL_VALUE=$4

HZ_JAR_URL=https://repo1.maven.org/maven2/com/hazelcast/hazelcast/${HZ_VERSION}/hazelcast-${HZ_VERSION}.jar
GCP_JAR_URL=https://repo1.maven.org/maven2/com/hazelcast/hazelcast-gcp/${GCP_VERSION}/hazelcast-gcp-${GCP_VERSION}.jar

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

    if wget -q "$GCP_JAR_URL"; then
        echo "GCP Plugin JAR downloaded succesfully."
    else
        echo "GCP Plugin JAR could NOT be downloaded!"
        exit 1;
    fi
popd

sed -i -e "s/LABEL_KEY/${LABEL_KEY}/g" ${HOME}/hazelcast.yaml
sed -i -e "s/LABEL_VALUE/${LABEL_VALUE}/g" ${HOME}/hazelcast.yaml

CLASSPATH="${HOME}/jars/hazelcast-${HZ_VERSION}.jar:${HOME}/jars/hazelcast-gcp-${GCP_VERSION}.jar:${HOME}/hazelcast.yaml"
nohup java -cp ${CLASSPATH} -server com.hazelcast.core.server.HazelcastMemberStarter &>> ${HOME}/logs/hazelcast.logs &
sleep 5
