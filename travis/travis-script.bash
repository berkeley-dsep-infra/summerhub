#!/bin/bash
# This script is used by travis to trigger deployments or builds

# .travis.yml:
# - DOCKER_PASSWORD (secure)
# - DOCKER_USERNAME (secure)
# - GCLOUD_ZONE
# - HUB_COURSE
# travis project settings:
# - encrypted_a0d548b80a29_key (created by 'travis encrypt-file')
# - encrypted_a0d548b80a29_iv  (created by 'travis encrypt-file')
# - GCLOUD_PROJECT (manual)

set -euo pipefail

CLUSTER="${TRAVIS_BRANCH}"

function prepare_gcloud {
    # Install gcloud
	if [ ! -d "$HOME/google-cloud-sdk/bin" ]; then
        rm -rf $HOME/google-cloud-sdk
        export CLOUDSDK_CORE_DISABLE_PROMPTS=1
        curl https://sdk.cloud.google.com | bash > /dev/null 2>&1
    fi
    source ${HOME}/google-cloud-sdk/path.bash.inc
	
    gcloud --quiet components update kubectl
}

function build {
	echo "Starting build..."
	PUSH=''

	if [[ ${TRAVIS_PULL_REQUEST} == 'false' ]]; then
		PUSH='--push'
		# Assume we have secrets!
		docker login -u $DOCKER_USERNAME -p "$DOCKER_PASSWORD"
	fi

	# Attempt to improve relability of pip installs:
	# https://github.com/travis-ci/travis-ci/issues/2389
	sudo sysctl net.ipv4.tcp_ecn=0

	cmd="./deploy.py --user-image-spec berkeleydsep/singleuser-summer build --commit-range ${TRAVIS_COMMIT_RANGE} ${PUSH}"
	echo ${cmd}
	${cmd}
}

function deploy {
	echo "Starting deploy..."

	prepare_gcloud

	# Encrypted variables are only set when we are not a PR
	# https://docs.travis-ci.com/user/pull-requests/#Pull-Requests-and-Security-Restrictions
	echo "Fetching gcloud service account credentials..."
	openssl aes-256-cbc \
		-K ${encrypted_a0d548b80a29_key} \
        -iv ${encrypted_a0d548b80a29_iv} \
		-in git-crypt.key.enc -out git-crypt.key -d
	chmod 0400 git-crypt.key

	git-crypt unlock git-crypt.key

	gcloud auth activate-service-account \
		--key-file hub/secrets/gcloud-creds.json
	gcloud config set project ${GCLOUD_PROJECT}

	gcloud container clusters get-credentials --zone=${GCLOUD_ZONE} \
		${CLUSTER}

	echo ./deploy.py deploy ${TRAVIS_BRANCH}
	./deploy.py deploy ${TRAVIS_BRANCH}

	echo "Done!"
}

# main
case $1 in
	build)  build ;;
	deploy) deploy ;;
esac
