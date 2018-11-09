#!/usr/bin/env bash

if [ "${1}" == "install" ]; then
    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
    chmod 700 get_helm.sh &&\
    ./get_helm.sh --version "${HELM_VERSION}" &&\
    helm version --client && rm ./get_helm.sh &&\
    helm init --client-only
    exit 0

elif [ "${1}" == "script" ]; then
    exit 0

elif [ "${1}" == "deploy" ]; then
    travis_ci_operator.sh github-update self master "
        cd charts_repository &&\
        helm package ../ckan --version "${TRAVIS_TAG}" &&\
        helm repo index . &&\
        cd .. &&\
        git add charts_repository/index.yaml charts_repository/ckan-${TRAVIS_TAG}.tgz
    " "upgrade helm chart repo to CKAN chart ${TRAVIS_TAG}"
    [ "$?" != "0" ] && exit 1
    if ! [ -z "${SLACK_TAG_NOTIFICATION_CHANNEL}" ] && ! [ -z "${SLACK_TAG_NOTIFICATION_WEBHOOK_URL}" ]; then
        ! curl -X POST \
               --data-urlencode "payload={\"channel\": \"#${SLACK_TAG_NOTIFICATION_CHANNEL}\", \"username\": \"CKAN Cloud\", \"text\": \"Released ckan-cloud-helm ${TRAVIS_TAG}\nhttps://github.com/ViderumGlobal/ckan-cloud-helm/releases/tag/${TRAVIS_TAG}\", \"icon_emoji\": \":female-technologist:\"}" \
               ${SLACK_TAG_NOTIFICATION_WEBHOOK_URL} && exit 1
    fi
    exit 0

fi

echo unexpected failure
exit 1
