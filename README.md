# CT dummy app

## build
* `git clone`
* `cd to repo root folder`
* `docker build . -t <dummy:0.1>`
* *or*
* `docker pull klimdos/dummy-flask-app:latest`
---
## re-tag
* `docker tag <dummy:0.1> artifactory.aws.wiley.com/docker/system/application:dummy.0.0.0`
* example: `docker tag klimdos/dummy-flask-app:latest artifactory.aws.wiley.com/docker/cmh/cmh-job-api:dummy.0.0.1`

## push
* `docker login artifactory.aws.wiley.com`
* Guide: [link](https://confluence.wiley.com/display/DEVOPS/Getting+started+with+Docker)
* `docker push artifactory.aws.wiley.com/docker/system/application:dummy.0.0.0`

## run
* `docker run -e PORT="8092" -p 8092:8092 artifactory.aws.wiley.com/docker/system/application:dummy.0.0.0`
* PORT is optional, if it is not set, web server will start on 8080 port
*or*
* run rollout job in Jenkins 