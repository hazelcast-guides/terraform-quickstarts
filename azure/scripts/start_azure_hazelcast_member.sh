#!/bin/bash
set -x

HZ_VERSION=$1
AZURE_VERSION=$2
#AZURE_TAG = $3


HZ_JAR_URL=https://repo1.maven.org/maven2/com/hazelcast/hazelcast/${HZ_VERSION}/hazelcast-${HZ_VERSION}.jar
AZURE_JAR_URL=https://repo1.maven.org/maven2/com/hazelcast/hazelcast-azure/${AZURE_VERSION}/hazelcast-azure-${AZURE_VERSION}.jar

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

    if wget -q "$AZURE_JAR_URL"; then
        echo "AZURE Plugin JAR downloaded succesfully."
    else
        echo "AZURE Plugin JAR could NOT be downloaded!"
        exit 1;
    fi
popd

#sed -i -e "s/KEY_VALUE_PAIR/${AZURE_TAG}/g" ${HOME}/hazelcast.yaml

CLASSPATH="${HOME}/jars/hazelcast-${HZ_VERSION}.jar:${HOME}/jars/hazelcast-azure-${AZURE_VERSION}.jar"
nohup java -cp ${CLASSPATH} -server com.hazelcast.core.server.HazelcastMemberStarter >> ${HOME}/logs/hazelcast.stderr.log 2>> ${HOME}/logs/hazelcast.stdout.log &
sleep 5
