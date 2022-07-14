#!/bin/bash

rm -rf orchestra-login-portal-argocd/templates 
mkdir orchestra-login-portal-argocd/templates

cp -r openunison-operator/templates/* orchestra-login-portal-argocd/templates/
#cp -r orchestra/templates/* orchestra-login-portal-argocd/templates/
#cp -r orchestra-login-portal/templates/* orchestra-login-portal-argocd/templates/