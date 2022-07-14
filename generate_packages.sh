#!/bin/bash


./generate-argocd.sh

export REPO="$1"

rm -rf /tmp/helm
mkdir /tmp/helm

for d in openunison-*/ ; do
    echo "$d"
    helm package $d
done

for d in orchestra*/ ; do
    echo "$d"
    helm package $d
done

aws s3 sync s3://tremolosecurity-maven/repository/helm$REPO/ /tmp/helm/ 

mv *.tgz /tmp/helm

helm repo index /tmp/helm --url https://nexus.tremolo.io/repository/helm$REPO

aws s3 sync /tmp/helm/ s3://tremolosecurity-maven/repository/helm$REPO/